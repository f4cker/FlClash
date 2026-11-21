//! The Unix socket endpoint of the IPC server: a private directory that only
//! this user can enter, and a socket file inside it that is removed on
//! shutdown only while it is still the one this process bound.
//!
//! `bind(2)` takes a path and has no directory-fd form on macOS, so the
//! directory is pinned by an open fd and its inode is checked before and after
//! the bind; every later operation on the socket file is relative to that fd.

use std::ffi::{CStr, CString};
use std::fs::{DirBuilder, File, Metadata, OpenOptions};
use std::io;
use std::mem::MaybeUninit;
use std::os::fd::AsRawFd;
use std::os::unix::ffi::OsStrExt;
use std::os::unix::fs::{DirBuilderExt, MetadataExt, OpenOptionsExt};
use std::path::{Path, PathBuf};

/// `sun_path` is 104 bytes on macOS, the terminating NUL included.
pub const MAX_SOCKET_PATH: usize = 103;

/// Marks a bind that failed because the name is taken. The Dart side looks for
/// it to retry under a fresh name; nothing at the taken name is touched.
pub const ADDR_IN_USE_TAG: &str = "EADDRINUSE";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct FileId {
    dev: u64,
    ino: u64,
}

impl FileId {
    fn of(metadata: &Metadata) -> Self {
        Self {
            dev: metadata.dev(),
            ino: metadata.ino(),
        }
    }

    #[allow(clippy::unnecessary_cast)]
    fn of_stat(stat: &libc::stat) -> Self {
        Self {
            dev: stat.st_dev as u64,
            ino: stat.st_ino as u64,
        }
    }
}

/// A directory that is a real directory, owned by this user and mode 0700,
/// held open so that it can be told apart from a replacement.
pub struct PrivateDir {
    path: PathBuf,
    dir: File,
    id: FileId,
    uid: u32,
}

impl PrivateDir {
    /// Creates the directory 0700 if it is absent. An existing one is used only
    /// if it already passes every check; it is never chmod-ed, chown-ed or
    /// deleted.
    pub fn claim(path: &Path) -> io::Result<Self> {
        match DirBuilder::new().mode(0o700).create(path) {
            Ok(()) => {}
            Err(error) if error.kind() == io::ErrorKind::AlreadyExists => {}
            Err(error) => {
                return Err(io::Error::new(
                    error.kind(),
                    format!(
                        "cannot create IPC socket directory {}: {error}",
                        path.display()
                    ),
                ))
            }
        }
        // SAFETY: geteuid() takes no arguments and cannot fail.
        let uid = unsafe { libc::geteuid() };
        let checked = std::fs::symlink_metadata(path)?;
        check_dir(path, &checked, uid)?;
        let dir = OpenOptions::new()
            .read(true)
            .custom_flags(libc::O_DIRECTORY | libc::O_NOFOLLOW | libc::O_CLOEXEC)
            .open(path)
            .map_err(|error| refused(path, &format!("cannot be opened: {error}")))?;
        let opened = dir.metadata()?;
        check_dir(path, &opened, uid)?;
        let id = FileId::of(&checked);
        if FileId::of(&opened) != id {
            return Err(refused(path, "was replaced while it was being opened"));
        }
        Ok(Self {
            path: path.to_owned(),
            dir,
            id,
            uid,
        })
    }

    /// The path still names the directory that was opened, and that directory
    /// still passes the checks.
    pub fn verify(&self) -> io::Result<()> {
        let current = std::fs::symlink_metadata(&self.path)
            .map_err(|error| refused(&self.path, &format!("disappeared: {error}")))?;
        check_dir(&self.path, &current, self.uid)?;
        if FileId::of(&current) != self.id {
            return Err(refused(&self.path, "was replaced after it was checked"));
        }
        check_dir(&self.path, &self.dir.metadata()?, self.uid)
    }

    fn stat_entry(&self, name: &CStr) -> io::Result<libc::stat> {
        let mut stat = MaybeUninit::<libc::stat>::uninit();
        // SAFETY: the fd is open for the lifetime of `self`, `name` is
        // NUL-terminated and `stat` is a valid out pointer.
        let result = unsafe {
            libc::fstatat(
                self.dir.as_raw_fd(),
                name.as_ptr(),
                stat.as_mut_ptr(),
                libc::AT_SYMLINK_NOFOLLOW,
            )
        };
        if result == 0 {
            // SAFETY: fstatat filled it in.
            Ok(unsafe { stat.assume_init() })
        } else {
            Err(io::Error::last_os_error())
        }
    }
}

fn check_dir(path: &Path, metadata: &Metadata, uid: u32) -> io::Result<()> {
    if metadata.file_type().is_symlink() {
        return Err(refused(path, "is a symbolic link"));
    }
    if !metadata.is_dir() {
        return Err(refused(path, "is not a directory"));
    }
    if metadata.uid() != uid {
        return Err(refused(
            path,
            &format!("is owned by uid {}, not {uid}", metadata.uid()),
        ));
    }
    let mode = metadata.mode() & 0o7777;
    if mode != 0o700 {
        return Err(refused(path, &format!("has mode {mode:o}, not 700")));
    }
    Ok(())
}

fn refused(path: &Path, reason: &str) -> io::Error {
    io::Error::new(
        io::ErrorKind::PermissionDenied,
        format!(
            "refusing IPC socket directory {}: it {reason}",
            path.display()
        ),
    )
}

/// Splits a socket address into its private directory and file name, and
/// claims the directory.
pub fn prepare(address: &str) -> io::Result<(PrivateDir, CString)> {
    if address.len() > MAX_SOCKET_PATH {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!(
                "IPC socket path is {} bytes, over the {MAX_SOCKET_PATH}-byte sun_path limit",
                address.len()
            ),
        ));
    }
    let path = Path::new(address);
    let (Some(parent), Some(name)) = (path.parent(), path.file_name()) else {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("IPC socket path {address} has no directory or file name"),
        ));
    };
    if parent.as_os_str().is_empty() || !path.is_absolute() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("IPC socket path {address} is not absolute"),
        ));
    }
    let name = CString::new(name.as_bytes())
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "IPC socket path has a NUL"))?;
    Ok((PrivateDir::claim(parent)?, name))
}

/// Explains a failed bind. Never deletes anything.
pub fn bind_error(address: &str, error: io::Error) -> io::Error {
    if error.kind() == io::ErrorKind::AddrInUse {
        io::Error::new(
            io::ErrorKind::AddrInUse,
            format!("{ADDR_IN_USE_TAG}: {address} already exists and was left alone"),
        )
    } else {
        error
    }
}

/// The socket file this process bound, identified by (dev, ino).
pub struct OwnedEndpoint {
    dir: PrivateDir,
    name: CString,
    id: FileId,
}

impl OwnedEndpoint {
    /// Records the socket file right after a successful bind. If the directory
    /// changed under the bind, or the name is not a socket of ours, it fails
    /// and leaves whatever is there alone.
    pub fn claim(dir: PrivateDir, name: CString) -> io::Result<Self> {
        dir.verify()?;
        let stat = dir.stat_entry(&name)?;
        if !is_socket_of(&stat, dir.uid) {
            return Err(io::Error::new(
                io::ErrorKind::PermissionDenied,
                "the bound IPC socket was replaced before it was recorded",
            ));
        }
        let endpoint = Self {
            id: FileId::of_stat(&stat),
            dir,
            name,
        };
        endpoint.restrict()?;
        if !endpoint.is_ours() {
            return Err(io::Error::new(
                io::ErrorKind::PermissionDenied,
                "the bound IPC socket was replaced while it was restricted",
            ));
        }
        Ok(endpoint)
    }

    /// macOS rejects fchmod on an unbound socket, and the mode `bind` gives
    /// the file follows the umask. The 0700 directory already keeps other
    /// users out; the mode is then tightened relative to the directory fd,
    /// without following a symlink, instead of by path.
    fn restrict(&self) -> io::Result<()> {
        // SAFETY: the fd is open and `name` is NUL-terminated.
        let result = unsafe {
            libc::fchmodat(
                self.dir.dir.as_raw_fd(),
                self.name.as_ptr(),
                0o600,
                libc::AT_SYMLINK_NOFOLLOW,
            )
        };
        if result == 0 {
            Ok(())
        } else {
            Err(io::Error::last_os_error())
        }
    }

    fn is_ours(&self) -> bool {
        self.dir.stat_entry(&self.name).is_ok_and(|stat| {
            is_socket_of(&stat, self.dir.uid) && FileId::of_stat(&stat) == self.id
        })
    }

    /// Unlinks the socket only if the name still holds the very socket that
    /// was bound. Returns whether it did.
    pub fn remove(self) -> bool {
        if !self.is_ours() {
            return false;
        }
        // SAFETY: the fd is open and `name` is NUL-terminated.
        unsafe { libc::unlinkat(self.dir.dir.as_raw_fd(), self.name.as_ptr(), 0) == 0 }
    }
}

fn is_socket_of(stat: &libc::stat, uid: u32) -> bool {
    stat.st_mode & libc::S_IFMT == libc::S_IFSOCK && stat.st_uid == uid
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::PermissionsExt;
    use std::os::unix::net::UnixListener;
    use std::sync::atomic::{AtomicUsize, Ordering};

    /// A fresh path under the temp dir that does not exist yet.
    fn fresh(label: &str) -> PathBuf {
        static NEXT: AtomicUsize = AtomicUsize::new(0);
        std::env::temp_dir().join(format!(
            "fep-{label}-{}-{}",
            std::process::id(),
            NEXT.fetch_add(1, Ordering::Relaxed)
        ))
    }

    fn kind(result: io::Result<impl Sized>) -> io::ErrorKind {
        result.err().expect("expected an error").kind()
    }

    #[test]
    fn an_absent_directory_is_created_owner_only() {
        let path = fresh("new");
        let dir = PrivateDir::claim(&path).unwrap();
        let mode = std::fs::symlink_metadata(&path).unwrap().mode() & 0o7777;
        assert_eq!(mode, 0o700);
        dir.verify().unwrap();
        std::fs::remove_dir(&path).unwrap();
    }

    #[test]
    fn a_symlinked_directory_is_refused_and_left_alone() {
        let target = fresh("target");
        std::fs::create_dir(&target).unwrap();
        std::fs::set_permissions(&target, std::fs::Permissions::from_mode(0o700)).unwrap();
        let link = fresh("link");
        std::os::unix::fs::symlink(&target, &link).unwrap();

        assert_eq!(
            kind(PrivateDir::claim(&link)),
            io::ErrorKind::PermissionDenied
        );

        assert!(std::fs::symlink_metadata(&link)
            .unwrap()
            .file_type()
            .is_symlink());
        std::fs::remove_file(&link).unwrap();
        std::fs::remove_dir(&target).unwrap();
    }

    #[test]
    fn a_directory_with_a_wider_mode_is_refused_and_not_chmod_ed() {
        let path = fresh("mode");
        std::fs::create_dir(&path).unwrap();
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();

        assert_eq!(
            kind(PrivateDir::claim(&path)),
            io::ErrorKind::PermissionDenied
        );

        assert_eq!(std::fs::metadata(&path).unwrap().mode() & 0o7777, 0o755);
        std::fs::remove_dir(&path).unwrap();
    }

    #[test]
    fn a_directory_owned_by_someone_else_is_refused() {
        let path = fresh("owner");
        std::fs::create_dir(&path).unwrap();
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o700)).unwrap();
        let metadata = std::fs::symlink_metadata(&path).unwrap();
        // SAFETY: geteuid() cannot fail.
        let other = unsafe { libc::geteuid() } + 1;

        let error = check_dir(&path, &metadata, other).unwrap_err();

        assert_eq!(error.kind(), io::ErrorKind::PermissionDenied);
        assert!(error.to_string().contains("owned by uid"), "{error}");
        std::fs::remove_dir(&path).unwrap();
    }

    #[test]
    fn a_root_owned_directory_is_refused() {
        // /tmp itself (or its target) is root's, and sticky 1777.
        let tmp = std::fs::canonicalize("/tmp").unwrap();
        assert_eq!(
            kind(PrivateDir::claim(&tmp)),
            io::ErrorKind::PermissionDenied
        );
    }

    #[test]
    fn a_regular_file_in_place_of_the_directory_is_refused() {
        let path = fresh("file");
        std::fs::write(&path, b"x").unwrap();
        assert_eq!(
            kind(PrivateDir::claim(&path)),
            io::ErrorKind::PermissionDenied
        );
        assert_eq!(std::fs::read(&path).unwrap(), b"x");
        std::fs::remove_file(&path).unwrap();
    }

    #[test]
    fn a_directory_replaced_after_the_check_fails_verification() {
        let path = fresh("swap");
        let dir = PrivateDir::claim(&path).unwrap();
        let moved = fresh("moved");
        std::fs::rename(&path, &moved).unwrap();
        std::fs::create_dir(&path).unwrap();
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o700)).unwrap();

        assert_eq!(kind(dir.verify()), io::ErrorKind::PermissionDenied);

        std::fs::remove_dir(&path).unwrap();
        std::fs::remove_dir(&moved).unwrap();
    }

    #[test]
    fn a_directory_replaced_between_check_and_bind_is_not_claimed_nor_cleaned() {
        let path = fresh("race");
        let dir = PrivateDir::claim(&path).unwrap();
        let moved = fresh("raced");
        std::fs::rename(&path, &moved).unwrap();
        std::fs::create_dir(&path).unwrap();
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o700)).unwrap();
        // The bind lands in the replacement directory.
        let socket = path.join("s");
        let listener = UnixListener::bind(&socket).unwrap();

        assert_eq!(
            kind(OwnedEndpoint::claim(dir, CString::new("s").unwrap())),
            io::ErrorKind::PermissionDenied
        );

        assert!(std::fs::symlink_metadata(&socket).is_ok());
        drop(listener);
        std::fs::remove_file(&socket).unwrap();
        std::fs::remove_dir(&path).unwrap();
        std::fs::remove_dir(&moved).unwrap();
    }

    #[test]
    fn a_path_over_the_sun_path_limit_is_rejected_before_anything_is_created() {
        let dir = fresh("long");
        let address = format!("{}/{}", dir.display(), "x".repeat(MAX_SOCKET_PATH));
        assert_eq!(kind(prepare(&address)), io::ErrorKind::InvalidInput);
        assert!(!dir.exists());
    }

    #[test]
    fn a_relative_path_is_rejected() {
        assert_eq!(
            kind(prepare("relative/core.sock")),
            io::ErrorKind::InvalidInput
        );
    }

    #[test]
    fn an_endpoint_replaced_by_another_file_is_not_removed() {
        let path = fresh("ep");
        let dir = PrivateDir::claim(&path).unwrap();
        let socket = path.join("s");
        let listener = UnixListener::bind(&socket).unwrap();
        let endpoint = OwnedEndpoint::claim(dir, CString::new("s").unwrap()).unwrap();
        drop(listener);
        std::fs::remove_file(&socket).unwrap();
        std::fs::write(&socket, b"replacement").unwrap();

        assert!(!endpoint.remove());

        assert_eq!(std::fs::read(&socket).unwrap(), b"replacement");
        std::fs::remove_file(&socket).unwrap();
        std::fs::remove_dir(&path).unwrap();
    }

    #[test]
    fn an_endpoint_replaced_by_another_socket_is_not_removed() {
        let path = fresh("ep2");
        let dir = PrivateDir::claim(&path).unwrap();
        let socket = path.join("s");
        drop(UnixListener::bind(&socket).unwrap());
        let endpoint = OwnedEndpoint::claim(dir, CString::new("s").unwrap()).unwrap();
        std::fs::remove_file(&socket).unwrap();
        let _other = UnixListener::bind(&socket).unwrap();

        assert!(!endpoint.remove());

        assert!(std::fs::symlink_metadata(&socket).is_ok());
        std::fs::remove_file(&socket).unwrap();
        std::fs::remove_dir(&path).unwrap();
    }

    #[test]
    fn an_endpoint_still_in_place_is_removed_and_its_mode_is_owner_only() {
        let path = fresh("own");
        let dir = PrivateDir::claim(&path).unwrap();
        let socket = path.join("s");
        let _listener = UnixListener::bind(&socket).unwrap();
        let endpoint = OwnedEndpoint::claim(dir, CString::new("s").unwrap()).unwrap();
        assert_eq!(
            std::fs::symlink_metadata(&socket).unwrap().mode() & 0o777,
            0o600
        );

        assert!(endpoint.remove());

        assert!(std::fs::symlink_metadata(&socket).is_err());
        std::fs::remove_dir(&path).unwrap();
    }

    #[test]
    fn a_non_socket_at_the_bound_name_is_not_claimed_nor_removed() {
        let path = fresh("nonsock");
        let dir = PrivateDir::claim(&path).unwrap();
        let file = path.join("s");
        std::fs::write(&file, b"keep").unwrap();

        assert_eq!(
            kind(OwnedEndpoint::claim(dir, CString::new("s").unwrap())),
            io::ErrorKind::PermissionDenied
        );

        assert_eq!(std::fs::read(&file).unwrap(), b"keep");
        std::fs::remove_file(&file).unwrap();
        std::fs::remove_dir(&path).unwrap();
    }
}
