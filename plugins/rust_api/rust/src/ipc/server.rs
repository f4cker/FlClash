#[cfg(target_os = "macos")]
use super::endpoint;
use super::outbox::Outbox;
use super::{access, frame, Event, EventSink};
use interprocess::local_socket::tokio::{prelude::*, Listener, RecvHalf, SendHalf, Stream};
use interprocess::local_socket::{GenericFilePath, ListenerOptions};
use std::io;
use std::sync::{mpsc, Arc, Mutex, MutexGuard, PoisonError};
use std::thread::{self, JoinHandle};
#[cfg(any(test, not(target_os = "macos")))]
use std::time::Duration;
use tokio::io::{AsyncWriteExt, BufReader};
use tokio::sync::oneshot;

#[cfg(not(target_os = "macos"))]
const STALE_SOCKET_RETRY_LIMIT: Duration = Duration::from_secs(1);

struct Control {
    events: Option<oneshot::Sender<EventSink>>,
    shutdown: Option<oneshot::Sender<()>>,
    worker: Option<JoinHandle<()>>,
}

/// A local socket serving one peer at a time from a thread of its own.
/// Dropping it ends that thread without waiting for it; `close` waits.
pub struct Server {
    outbox: Arc<Outbox>,
    control: Mutex<Control>,
}

impl Server {
    /// Returns once `address` is bound. Peers that connect before `events`
    /// attaches a sink wait in the backlog.
    pub fn bind(address: String) -> io::Result<Self> {
        let outbox = Arc::new(Outbox::default());
        let (bound_tx, bound_rx) = mpsc::sync_channel(1);
        let (events_tx, events_rx) = oneshot::channel();
        let (shutdown_tx, shutdown_rx) = oneshot::channel();
        let worker_outbox = Arc::clone(&outbox);
        let worker = thread::Builder::new()
            .name("ipc-server".into())
            .spawn(move || run(address, bound_tx, events_rx, shutdown_rx, worker_outbox))?;
        bound_rx
            .recv()
            .map_err(|_| io::Error::other("IPC server thread ended before binding"))??;
        Ok(Self {
            outbox,
            control: Mutex::new(Control {
                events: Some(events_tx),
                shutdown: Some(shutdown_tx),
                worker: Some(worker),
            }),
        })
    }

    pub fn events(&self, sink: EventSink) {
        if let Some(events) = self.control().events.take() {
            let _ = events.send(sink);
        }
    }

    pub fn send(&self, payload: &[u8]) -> io::Result<()> {
        self.outbox.push(frame::encode(payload)?)
    }

    pub fn close(&self) {
        let worker = {
            let mut control = self.control();
            control.events = None;
            control.shutdown = None;
            control.worker.take()
        };
        if let Some(worker) = worker {
            let _ = worker.join();
        }
    }

    fn control(&self) -> MutexGuard<'_, Control> {
        self.control.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

fn run(
    address: String,
    bound: mpsc::SyncSender<io::Result<()>>,
    events: oneshot::Receiver<EventSink>,
    shutdown: oneshot::Receiver<()>,
    outbox: Arc<Outbox>,
) {
    let runtime = match tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
    {
        Ok(runtime) => runtime,
        Err(error) => {
            let _ = bound.send(Err(error));
            return;
        }
    };
    runtime.block_on(async {
        let (listener, endpoint) = match listen(&address) {
            Ok(bound) => bound,
            Err(error) => {
                let _ = bound.send(Err(error));
                return;
            }
        };
        let _ = bound.send(Ok(()));
        let serve = async {
            if let Ok(emit) = events.await {
                accept_peers(&listener, &emit, &outbox).await;
            }
        };
        tokio::select! {
            _ = serve => {}
            _ = shutdown => {}
        }
        outbox.close();
        drop(listener);
        release(endpoint);
    });
}

/// Linux keeps `/tmp/FlClashSocket_<n>.sock`, the only form its root helper
/// accepts (services/helper hub.rs `is_allowed_core_address`); Windows keeps
/// its pipe. Both are bound exactly as before.
#[cfg(not(target_os = "macos"))]
fn listen(address: &str) -> io::Result<(Listener, ())> {
    let options = ListenerOptions::new()
        .name(address.to_fs_name::<GenericFilePath>()?)
        .try_overwrite(true)
        .max_spin_time(STALE_SOCKET_RETRY_LIMIT);
    let listener = access::owner_only(options).create_tokio()?;
    access::restrict_socket(address)?;
    Ok((listener, ()))
}

#[cfg(not(target_os = "macos"))]
fn release(_endpoint: ()) {}

/// Binds without overwriting: a taken name fails with `EADDRINUSE` and is left
/// alone, and the library never unlinks the name on drop. The socket file is
/// removed by `release` only while it is still the one bound here.
#[cfg(target_os = "macos")]
fn listen(address: &str) -> io::Result<(Listener, endpoint::OwnedEndpoint)> {
    let (dir, name) = endpoint::prepare(address)?;
    let options = ListenerOptions::new()
        .name(address.to_fs_name::<GenericFilePath>()?)
        .try_overwrite(false)
        .reclaim_name(false);
    let listener = access::owner_only(options)
        .create_tokio()
        .map_err(|error| endpoint::bind_error(address, error))?;
    let endpoint = endpoint::OwnedEndpoint::claim(dir, name)?;
    Ok((listener, endpoint))
}

#[cfg(target_os = "macos")]
fn release(endpoint: endpoint::OwnedEndpoint) {
    endpoint.remove();
}

async fn accept_peers(listener: &Listener, emit: &EventSink, outbox: &Outbox) {
    loop {
        let stream = match listener.accept().await {
            Ok(stream) => stream,
            Err(error) => {
                emit(Event::Failed(format!("accept error: {error}")));
                return;
            }
        };
        let pid = match access::admit(&stream) {
            Ok(pid) => pid,
            Err(error) => {
                if cfg!(debug_assertions) {
                    eprintln!("[IPC] rejected connection: {error}");
                }
                continue;
            }
        };
        // The host may send as soon as it sees `Connected`.
        outbox.open();
        let listening = emit(Event::Connected { pid });
        let error = if listening {
            exchange(stream, emit, outbox).await
        } else {
            None
        };
        outbox.close();
        if !listening || !emit(Event::Disconnected { error }) {
            return;
        }
    }
}

async fn exchange(stream: Stream, emit: &EventSink, outbox: &Outbox) -> Option<String> {
    let (reader, writer) = stream.split();
    let result = tokio::select! {
        result = receive(reader, emit) => result,
        result = transmit(writer, outbox) => result,
    };
    match result {
        Err(error) if !is_peer_gone(&error) => Some(error.to_string()),
        _ => None,
    }
}

async fn receive(reader: RecvHalf, emit: &EventSink) -> io::Result<()> {
    let mut reader = BufReader::new(reader);
    loop {
        let payload = frame::read(&mut reader).await?;
        if !emit(Event::Message(payload)) {
            return Ok(());
        }
    }
}

async fn transmit(mut writer: SendHalf, outbox: &Outbox) -> io::Result<()> {
    loop {
        let frame = outbox.next().await;
        writer.write_all(&frame).await?;
    }
}

fn is_peer_gone(error: &io::Error) -> bool {
    matches!(
        error.kind(),
        io::ErrorKind::UnexpectedEof | io::ErrorKind::ConnectionReset | io::ErrorKind::BrokenPipe
    )
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;
    use std::io::{Read, Write};
    use std::os::unix::fs::PermissionsExt;
    use std::os::unix::net::{UnixListener, UnixStream};
    use std::path::Path;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::mpsc::{channel, Receiver};
    use std::time::Instant;

    const WAIT: Duration = Duration::from_secs(5);

    /// A fresh owner-only directory per call, as the app's private one.
    fn private_dir() -> std::path::PathBuf {
        use std::os::unix::fs::DirBuilderExt;

        static NEXT: AtomicUsize = AtomicUsize::new(0);
        let dir = std::env::temp_dir().join(format!(
            "fipc-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed),
        ));
        std::fs::DirBuilder::new().mode(0o700).create(&dir).unwrap();
        dir
    }

    fn socket_path() -> String {
        private_dir().join("core.sock").to_str().unwrap().to_owned()
    }

    fn attach(server: &Server) -> Receiver<Event> {
        let (tx, rx) = channel();
        server.events(Box::new(move |event| tx.send(event).is_ok()));
        rx
    }

    fn serve(path: &str) -> (Server, Receiver<Event>) {
        let server = Server::bind(path.to_owned()).unwrap();
        let events = attach(&server);
        (server, events)
    }

    fn connect(path: &str) -> UnixStream {
        let peer = UnixStream::connect(path).unwrap();
        peer.set_read_timeout(Some(WAIT)).unwrap();
        peer
    }

    fn next(events: &Receiver<Event>) -> Event {
        events.recv_timeout(WAIT).expect("no IPC event arrived")
    }

    fn expect_connected(events: &Receiver<Event>) {
        assert!(matches!(next(events), Event::Connected { .. }));
    }

    fn write_frame(peer: &mut UnixStream, payload: &[u8]) {
        peer.write_all(&frame::encode(payload).unwrap()).unwrap();
    }

    fn read_frame(peer: &mut UnixStream) -> Vec<u8> {
        let mut header = [0; 4];
        peer.read_exact(&mut header).unwrap();
        let mut payload = vec![0; u32::from_le_bytes(header) as usize];
        peer.read_exact(&mut payload).unwrap();
        payload
    }

    fn wait_until(condition: impl Fn() -> bool) {
        let deadline = Instant::now() + WAIT;
        while !condition() {
            assert!(Instant::now() < deadline, "condition never held");
            thread::sleep(Duration::from_millis(5));
        }
    }

    #[test]
    fn frames_flow_both_ways_between_connect_and_disconnect() {
        let path = socket_path();
        let (server, events) = serve(&path);
        let mut peer = connect(&path);
        expect_connected(&events);

        write_frame(&mut peer, b"ping");
        assert_eq!(next(&events), Event::Message(b"ping".to_vec()));

        server.send(b"pong").unwrap();
        assert_eq!(read_frame(&mut peer), b"pong");

        drop(peer);
        assert_eq!(next(&events), Event::Disconnected { error: None });
        server.close();
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn a_connection_reports_the_peer_process() {
        let path = socket_path();
        let (server, events) = serve(&path);
        let _peer = connect(&path);

        let pid = Some(std::process::id());
        assert_eq!(next(&events), Event::Connected { pid });
        server.close();
    }

    #[test]
    fn frames_sent_in_a_burst_arrive_in_order() {
        let path = socket_path();
        let (server, events) = serve(&path);
        let mut peer = connect(&path);
        expect_connected(&events);

        for index in 0..200_u32 {
            server.send(&index.to_le_bytes()).unwrap();
            write_frame(&mut peer, &index.to_le_bytes());
        }

        for index in 0..200_u32 {
            assert_eq!(read_frame(&mut peer), index.to_le_bytes());
            assert_eq!(next(&events), Event::Message(index.to_le_bytes().to_vec()));
        }
        server.close();
    }

    #[test]
    fn a_frame_larger_than_the_socket_buffer_arrives_whole() {
        let path = socket_path();
        let (server, events) = serve(&path);
        let mut peer = connect(&path);
        expect_connected(&events);
        let payload: Vec<u8> = (0..4 * 1024 * 1024).map(|index| index as u8).collect();

        server.send(&payload).unwrap();
        assert_eq!(read_frame(&mut peer), payload);

        write_frame(&mut peer, &payload);
        assert_eq!(next(&events), Event::Message(payload));
        server.close();
    }

    #[test]
    fn the_next_peer_is_served_after_the_last_one_left() {
        let path = socket_path();
        let (server, events) = serve(&path);
        drop(connect(&path));
        expect_connected(&events);
        assert_eq!(next(&events), Event::Disconnected { error: None });

        let mut peer = connect(&path);
        expect_connected(&events);
        server.send(b"again").unwrap();

        assert_eq!(read_frame(&mut peer), b"again");
        server.close();
    }

    #[test]
    fn a_send_without_a_peer_is_refused() {
        let path = socket_path();
        let (server, events) = serve(&path);
        assert_eq!(
            server.send(b"early").unwrap_err().kind(),
            io::ErrorKind::NotConnected,
        );

        drop(connect(&path));
        expect_connected(&events);
        assert_eq!(next(&events), Event::Disconnected { error: None });

        assert_eq!(
            server.send(b"late").unwrap_err().kind(),
            io::ErrorKind::NotConnected,
        );
        server.close();
    }

    #[test]
    fn a_peer_that_connects_before_events_are_attached_is_still_reported() {
        let path = socket_path();
        let server = Server::bind(path.clone()).unwrap();
        let mut peer = connect(&path);
        write_frame(&mut peer, b"early");

        let events = attach(&server);

        expect_connected(&events);
        assert_eq!(next(&events), Event::Message(b"early".to_vec()));
        server.close();
    }

    #[test]
    fn an_oversized_frame_ends_the_connection_with_an_error() {
        let path = socket_path();
        let (server, events) = serve(&path);
        let mut peer = connect(&path);
        expect_connected(&events);

        let header = (frame::MAX_FRAME_SIZE as u32 + 1).to_le_bytes();
        peer.write_all(&header).unwrap();

        let Event::Disconnected { error: Some(error) } = next(&events) else {
            panic!("the connection did not end with an error");
        };
        assert!(error.contains("exceeds"), "{error}");
        assert_eq!(peer.read(&mut [0; 1]).unwrap(), 0);
        server.close();
    }

    #[test]
    fn closing_disconnects_the_peer_and_removes_the_socket() {
        let path = socket_path();
        let (server, events) = serve(&path);
        let mut peer = connect(&path);
        expect_connected(&events);

        server.close();

        assert_eq!(peer.read(&mut [0; 1]).unwrap(), 0);
        assert!(!Path::new(&path).exists());
        assert!(events.recv_timeout(WAIT).is_err());
        assert_eq!(
            server.send(b"closed").unwrap_err().kind(),
            io::ErrorKind::NotConnected,
        );
        server.close();
    }

    #[test]
    fn dropping_the_server_releases_the_socket() {
        let path = socket_path();
        let (server, _events) = serve(&path);

        drop(server);

        wait_until(|| !Path::new(&path).exists());
    }

    #[test]
    fn the_server_ends_once_nobody_listens_for_events() {
        let path = socket_path();
        let (_server, events) = serve(&path);
        drop(events);

        let _peer = connect(&path);

        wait_until(|| !Path::new(&path).exists());
    }

    #[cfg(not(target_os = "macos"))]
    #[test]
    fn binding_takes_over_a_stale_socket_file() {
        let path = socket_path();
        drop(UnixListener::bind(&path).unwrap());
        assert!(Path::new(&path).exists());

        let (server, events) = serve(&path);
        let _peer = connect(&path);

        expect_connected(&events);
        server.close();
    }

    #[cfg(target_os = "macos")]
    fn identity(path: &str) -> (u64, u64) {
        use std::os::unix::fs::MetadataExt;

        let metadata = std::fs::symlink_metadata(path).unwrap();
        (metadata.dev(), metadata.ino())
    }

    #[cfg(target_os = "macos")]
    fn assert_in_use(error: io::Error) {
        assert_eq!(error.kind(), io::ErrorKind::AddrInUse);
        assert!(
            error.to_string().starts_with(endpoint::ADDR_IN_USE_TAG),
            "{error}"
        );
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn two_listeners_on_different_names_in_one_directory_both_serve() {
        let dir = private_dir();
        let first = dir.join("a.sock").to_str().unwrap().to_owned();
        let second = dir.join("b.sock").to_str().unwrap().to_owned();
        let (one, one_events) = serve(&first);
        let (two, two_events) = serve(&second);

        let _a = connect(&first);
        let _b = connect(&second);

        expect_connected(&one_events);
        expect_connected(&two_events);
        one.close();
        two.close();
        assert!(!Path::new(&first).exists() && !Path::new(&second).exists());
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn a_stale_socket_at_the_name_is_left_alone_and_fails_with_addr_in_use() {
        let path = socket_path();
        drop(UnixListener::bind(&path).unwrap());
        let before = identity(&path);

        assert_in_use(Server::bind(path.clone()).err().unwrap());

        assert_eq!(identity(&path), before);
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn a_live_listener_is_never_taken_over() {
        let path = socket_path();
        let (server, events) = serve(&path);
        let before = identity(&path);

        assert_in_use(Server::bind(path.clone()).err().unwrap());

        assert_eq!(identity(&path), before);
        let _peer = connect(&path);
        expect_connected(&events);
        server.close();
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn a_regular_file_at_the_name_is_left_alone_and_fails_with_addr_in_use() {
        let path = socket_path();
        std::fs::write(&path, b"keep").unwrap();

        assert_in_use(Server::bind(path.clone()).err().unwrap());

        assert_eq!(std::fs::read(&path).unwrap(), b"keep");
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn repeated_binds_to_a_taken_name_all_fail_and_delete_nothing() {
        let path = socket_path();
        drop(UnixListener::bind(&path).unwrap());
        let before = identity(&path);

        for _ in 0..8 {
            assert_in_use(Server::bind(path.clone()).err().unwrap());
        }

        assert_eq!(identity(&path), before);
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn a_symlinked_socket_directory_is_refused() {
        let target = private_dir();
        let link = target.with_extension("link");
        std::os::unix::fs::symlink(&target, &link).unwrap();
        let path = link.join("core.sock").to_str().unwrap().to_owned();

        let error = Server::bind(path).err().unwrap();

        assert_eq!(error.kind(), io::ErrorKind::PermissionDenied, "{error}");
        assert!(!target.join("core.sock").exists());
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn a_socket_directory_with_a_wider_mode_is_refused_and_kept() {
        let dir = private_dir();
        std::fs::set_permissions(&dir, std::fs::Permissions::from_mode(0o755)).unwrap();
        let path = dir.join("core.sock").to_str().unwrap().to_owned();

        let error = Server::bind(path.clone()).err().unwrap();

        assert_eq!(error.kind(), io::ErrorKind::PermissionDenied, "{error}");
        assert_eq!(
            std::fs::metadata(&dir).unwrap().permissions().mode() & 0o7777,
            0o755
        );
        assert!(!Path::new(&path).exists());
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn an_absent_socket_directory_is_created_owner_only() {
        let dir = private_dir().join("app-501");
        let path = dir.join("core.sock").to_str().unwrap().to_owned();

        let server = Server::bind(path).unwrap();

        assert_eq!(
            std::fs::metadata(&dir).unwrap().permissions().mode() & 0o7777,
            0o700
        );
        server.close();
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn a_socket_replaced_before_shutdown_is_not_deleted() {
        let path = socket_path();
        let (server, _events) = serve(&path);
        std::fs::remove_file(&path).unwrap();
        std::fs::write(&path, b"replacement").unwrap();

        server.close();

        assert_eq!(std::fs::read(&path).unwrap(), b"replacement");
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn a_socket_replaced_by_another_listener_is_not_deleted() {
        let path = socket_path();
        let (server, _events) = serve(&path);
        std::fs::remove_file(&path).unwrap();
        let other = UnixListener::bind(&path).unwrap();
        let before = identity(&path);

        server.close();

        assert_eq!(identity(&path), before);
        drop(UnixStream::connect(&path).unwrap());
        drop(other);
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn a_socket_directory_replaced_after_binding_is_left_alone_at_shutdown() {
        let dir = private_dir();
        let path = dir.join("core.sock").to_str().unwrap().to_owned();
        let (server, _events) = serve(&path);
        let moved = dir.with_extension("moved");
        std::fs::rename(&dir, &moved).unwrap();
        std::fs::create_dir(&dir).unwrap();
        std::fs::set_permissions(&dir, std::fs::Permissions::from_mode(0o700)).unwrap();
        drop(UnixListener::bind(&path).unwrap());
        let replacement = identity(&path);

        server.close();

        // The replacement under the old path is untouched; only the socket in
        // the directory that was actually bound into (now moved) is removed.
        assert_eq!(identity(&path), replacement);
        assert!(!moved.join("core.sock").exists());
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn normal_shutdown_removes_only_its_own_socket() {
        let dir = private_dir();
        let path = dir.join("core.sock").to_str().unwrap().to_owned();
        let neighbour = dir.join("other.sock");
        std::fs::write(&neighbour, b"neighbour").unwrap();
        let (server, _events) = serve(&path);

        server.close();

        assert!(!Path::new(&path).exists());
        assert_eq!(std::fs::read(&neighbour).unwrap(), b"neighbour");
        assert!(dir.is_dir());
    }

    #[test]
    fn the_socket_is_reachable_by_its_owner_only() {
        let path = socket_path();
        let server = Server::bind(path.clone()).unwrap();

        let mode = std::fs::metadata(&path).unwrap().permissions().mode();

        assert_eq!(mode & 0o777, 0o600);
        server.close();
    }

    #[test]
    fn an_unusable_address_fails_the_bind() {
        let path = private_dir()
            .join("missing-parent")
            .join("nested")
            .join("core.sock");

        assert!(Server::bind(path.to_str().unwrap().to_owned()).is_err());
        assert!(!path.parent().unwrap().exists());
    }
}
