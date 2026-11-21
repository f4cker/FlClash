//! The Unix socket endpoint of the IPC server: a private directory that only
//! this user can enter, and a socket file inside it that is removed on
//! shutdown only while it is still the one this process bound.
//!
//! The directory sits directly inside the per-user temp dir the system hands
//! out (`confstr(_CS_DARWIN_USER_TEMP_DIR)`, `/var/folders/…/T`), which only
//! this user can write to, so no other user can pre-create or squat it. There
//! is no fallback to `/tmp` or to `$TMPDIR`.
//!
//! `bind(2)` takes a path and has no directory-fd form on macOS, so the
//! directory is pinned by an open fd and its inode is checked before and after
//! the bind; every later operation on the socket file is relative to that fd.

use std::ffi::{CStr, CString, OsStr};
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
    /// `claim_with` as this user, with the real mkdir.
    #[cfg(test)]
    fn claim(path: &Path) -> io::Result<Self> {
        Self::claim_with(path, current_uid(), mkdir_private)
    }

    /// Creates the directory 0700 if it is absent. An existing one is used only
    /// if it already passes every check; it is never chmod-ed, chown-ed or
    /// deleted. `uid` and `mkdir` are injectable so that another user, or a
    /// umask that strips owner bits, can be simulated in tests.
    fn claim_with(
        path: &Path,
        uid: u32,
        mkdir: impl FnOnce(&Path) -> io::Result<()>,
    ) -> io::Result<Self> {
        let created = match mkdir(path) {
            Ok(()) => true,
            Err(error) if error.kind() == io::ErrorKind::AlreadyExists => false,
            Err(error) => {
                return Err(io::Error::new(
                    error.kind(),
                    format!(
                        "cannot create IPC socket directory {}: {error}",
                        path.display()
                    ),
                ))
            }
        };
        let checked = std::fs::symlink_metadata(path)?;
        // Only a directory made by this very call may still have its mode
        // fixed; it is checked in full after that.
        if created {
            check_owned_dir(path, &checked, uid)?;
        } else {
            check_dir(path, &checked, uid)?;
        }
        let dir = OpenOptions::new()
            .read(true)
            .custom_flags(libc::O_DIRECTORY | libc::O_NOFOLLOW | libc::O_CLOEXEC)
            .open(path)
            .map_err(|error| refused(path, &format!("cannot be opened: {error}")))?;
        let mut opened = dir.metadata()?;
        check_owned_dir(path, &opened, uid)?;
        let id = FileId::of(&checked);
        if FileId::of(&opened) != id {
            return Err(refused(path, "was replaced while it was being opened"));
        }
        if created && opened.mode() & 0o7777 != 0o700 {
            // The umask stripped bits from the 0700 mkdir; fix it through the
            // fd just verified to be the directory created here.
            // SAFETY: the fd is open.
            if unsafe { libc::fchmod(dir.as_raw_fd(), 0o700) } != 0 {
                return Err(io::Error::last_os_error());
            }
            opened = dir.metadata()?;
        }
        check_dir(path, &opened, uid)?;
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
    check_owned_dir(path, metadata, uid)?;
    let mode = metadata.mode() & 0o7777;
    if mode != 0o700 {
        return Err(refused(path, &format!("has mode {mode:o}, not 700")));
    }
    Ok(())
}

/// A real directory owned by `uid`, whatever its mode.
fn check_owned_dir(path: &Path, metadata: &Metadata, uid: u32) -> io::Result<()> {
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

fn current_uid() -> u32 {
    // SAFETY: geteuid() takes no arguments and cannot fail.
    unsafe { libc::geteuid() }
}

fn mkdir_private(path: &Path) -> io::Result<()> {
    DirBuilder::new().mode(0o700).create(path)
}

/// The per-user temp dir from `confstr(_CS_DARWIN_USER_TEMP_DIR)`. `$TMPDIR`
/// is not consulted: the environment can point it anywhere.
pub fn user_temp_dir() -> io::Result<PathBuf> {
    user_temp_dir_with(|buf, len| {
        // SAFETY: `buf` is null with `len` 0, or valid for `len` bytes.
        unsafe { libc::confstr(libc::_CS_DARWIN_USER_TEMP_DIR, buf, len) }
    })
}

fn user_temp_dir_with(confstr: impl Fn(*mut libc::c_char, usize) -> usize) -> io::Result<PathBuf> {
    let unavailable = |why: String| {
        io::Error::new(
            io::ErrorKind::NotFound,
            format!(
                "the per-user temp dir is unavailable: confstr(_CS_DARWIN_USER_TEMP_DIR) {why}; \
                 not falling back to /tmp"
            ),
        )
    };
    let needed = confstr(std::ptr::null_mut(), 0);
    if needed == 0 {
        return Err(unavailable(format!(
            "failed: {}",
            io::Error::last_os_error()
        )));
    }
    let mut buffer = vec![0_u8; needed];
    let written = confstr(buffer.as_mut_ptr().cast(), buffer.len());
    if written == 0 || written > buffer.len() {
        return Err(unavailable("failed on the second call".into()));
    }
    let value = CStr::from_bytes_until_nul(&buffer)
        .map_err(|_| unavailable("returned no terminating NUL".into()))?;
    let path = PathBuf::from(OsStr::from_bytes(value.to_bytes()));
    if !path.is_absolute() {
        return Err(unavailable(format!(
            "returned {path:?}, not an absolute path"
        )));
    }
    Ok(path)
}

/// The base must be a real directory, owned by `uid`, that nobody else can
/// enter or write to (mode `& 077 == 0`; the system makes it 0700).
fn check_base(base: &Path, uid: u32) -> io::Result<()> {
    let refused = |reason: String| {
        io::Error::new(
            io::ErrorKind::PermissionDenied,
            format!(
                "refusing per-user temp dir {}: it {reason}; not falling back to /tmp",
                base.display()
            ),
        )
    };
    let metadata = std::fs::symlink_metadata(base)
        .map_err(|error| refused(format!("cannot be inspected: {error}")))?;
    if metadata.file_type().is_symlink() {
        return Err(refused("is a symbolic link".into()));
    }
    if !metadata.is_dir() {
        return Err(refused("is not a directory".into()));
    }
    if metadata.uid() != uid {
        return Err(refused(format!(
            "is owned by uid {}, not {uid}",
            metadata.uid()
        )));
    }
    let mode = metadata.mode() & 0o7777;
    if mode & 0o077 != 0 {
        return Err(refused(format!("has mode {mode:o}, open to other users")));
    }
    Ok(())
}

/// Splits a socket address into its private directory and file name, checks
/// that the directory sits directly in the per-user temp dir, and claims it.
pub fn prepare(address: &str) -> io::Result<(PrivateDir, CString)> {
    prepare_in(address, &user_temp_dir()?, current_uid())
}

fn prepare_in(address: &str, base: &Path, uid: u32) -> io::Result<(PrivateDir, CString)> {
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
    if parent.parent() != Some(base) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!(
                "IPC socket directory {} is not directly inside the per-user temp dir {}",
                parent.display(),
                base.display()
            ),
        ));
    }
    check_base(base, uid)?;
    Ok((PrivateDir::claim_with(parent, uid, mkdir_private)?, name))
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
        user_temp_dir().unwrap().join(format!(
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

    fn entries(path: &Path) -> Vec<std::ffi::OsString> {
        let mut names: Vec<_> = std::fs::read_dir(path)
            .unwrap()
            .map(|entry| entry.unwrap().file_name())
            .collect();
        names.sort();
        names
    }

    #[test]
    fn claiming_a_directory_owned_by_someone_else_changes_nothing() {
        // As seen by another uid, this 0700 directory is someone else's.
        let path = fresh("other");
        std::fs::create_dir(&path).unwrap();
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o700)).unwrap();
        let other = current_uid() + 1;

        let error = PrivateDir::claim_with(&path, other, mkdir_private)
            .err()
            .unwrap();

        assert_eq!(error.kind(), io::ErrorKind::PermissionDenied);
        assert!(error.to_string().contains("owned by uid"), "{error}");
        assert_eq!(
            std::fs::symlink_metadata(&path).unwrap().mode() & 0o7777,
            0o700
        );
        assert!(entries(&path).is_empty());
        std::fs::remove_dir(&path).unwrap();
    }

    #[test]
    fn claiming_a_failing_directory_creates_and_deletes_nothing() {
        let path = fresh("keep");
        std::fs::create_dir(&path).unwrap();
        std::fs::write(path.join("sentinel"), b"keep").unwrap();
        for mode in [0o755, 0o500, 0o711] {
            std::fs::set_permissions(&path, std::fs::Permissions::from_mode(mode)).unwrap();
            let before = entries(&path);

            assert_eq!(
                kind(PrivateDir::claim(&path)),
                io::ErrorKind::PermissionDenied
            );

            assert_eq!(
                std::fs::symlink_metadata(&path).unwrap().mode() & 0o7777,
                mode
            );
            assert_eq!(entries(&path), before);
        }
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o700)).unwrap();
        assert_eq!(std::fs::read(path.join("sentinel")).unwrap(), b"keep");
        std::fs::remove_dir_all(&path).unwrap();
    }

    /// mkdir as a umask of 0277 would leave it: owner r-x only.
    fn stripped_mkdir(path: &Path) -> io::Result<()> {
        std::fs::create_dir(path)?;
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o500))
    }

    #[test]
    fn a_directory_created_here_under_a_stripping_umask_is_fixed_to_0700() {
        let path = fresh("umask");

        let dir = PrivateDir::claim_with(&path, current_uid(), stripped_mkdir).unwrap();

        assert_eq!(
            std::fs::symlink_metadata(&path).unwrap().mode() & 0o7777,
            0o700
        );
        dir.verify().unwrap();
        std::fs::remove_dir(&path).unwrap();
    }

    #[test]
    fn a_pre_existing_directory_is_never_fixed_even_with_the_same_mode() {
        let path = fresh("preexisting");
        stripped_mkdir(&path).unwrap();

        // mkdir reports EEXIST, so this call did not create it.
        assert_eq!(
            kind(PrivateDir::claim_with(&path, current_uid(), stripped_mkdir)),
            io::ErrorKind::PermissionDenied
        );

        assert_eq!(
            std::fs::symlink_metadata(&path).unwrap().mode() & 0o7777,
            0o500
        );
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o700)).unwrap();
        std::fs::remove_dir(&path).unwrap();
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

    /// An address of exactly `len` bytes in a fresh subdir of the real base.
    fn address_of_len(len: usize) -> (PathBuf, String) {
        let dir = fresh("len");
        let prefix = format!("{}/", dir.display());
        assert!(prefix.len() < len, "the base is too long for this test");
        let address = format!("{prefix}{}", "n".repeat(len - prefix.len()));
        assert_eq!(address.len(), len);
        (dir, address)
    }

    #[test]
    fn a_path_exactly_at_the_sun_path_limit_is_accepted() {
        let (dir, address) = address_of_len(MAX_SOCKET_PATH);

        let (claimed, _name) = prepare(&address).unwrap();

        claimed.verify().unwrap();
        std::fs::remove_dir(&dir).unwrap();
    }

    #[test]
    fn a_path_one_byte_over_the_limit_is_rejected_before_anything_is_created() {
        let (dir, address) = address_of_len(MAX_SOCKET_PATH + 1);

        let error = prepare(&address).err().unwrap();

        assert_eq!(error.kind(), io::ErrorKind::InvalidInput);
        assert!(error.to_string().contains("sun_path"), "{error}");
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
    fn the_base_comes_from_confstr_and_is_ours_and_private() {
        let base = user_temp_dir().unwrap();

        assert!(base.is_absolute());
        check_base(&base, current_uid()).unwrap();
    }

    #[test]
    fn a_confstr_failure_is_an_error_without_fallback() {
        let error = user_temp_dir_with(|_, _| 0).unwrap_err();

        assert_eq!(error.kind(), io::ErrorKind::NotFound);
        assert!(
            error.to_string().contains("not falling back to /tmp"),
            "{error}"
        );
    }

    #[test]
    fn a_relative_confstr_result_is_an_error() {
        let fake = |buf: *mut libc::c_char, len: usize| {
            let value = b"relative/T/\0";
            if !buf.is_null() && len >= value.len() {
                // SAFETY: `buf` holds `len` bytes.
                unsafe { std::ptr::copy_nonoverlapping(value.as_ptr().cast(), buf, value.len()) };
            }
            value.len()
        };

        assert_eq!(
            user_temp_dir_with(fake).unwrap_err().kind(),
            io::ErrorKind::NotFound
        );
    }

    #[test]
    fn another_users_base_is_refused() {
        // Our own base, seen by a different uid, is someone else's.
        let base = user_temp_dir().unwrap();
        let other = current_uid() + 1;
        let address = format!("{}/sub-{}/core.sock", base.display(), std::process::id());

        let error = prepare_in(&address, &base, other).err().unwrap();

        assert_eq!(error.kind(), io::ErrorKind::PermissionDenied);
        assert!(error.to_string().contains("owned by uid"), "{error}");
        assert!(!Path::new(&address).parent().unwrap().exists());
    }

    #[test]
    fn a_missing_base_is_refused_without_fallback() {
        let base = fresh("nobase");
        let address = format!("{}/sub/core.sock", base.display());

        let error = prepare_in(&address, &base, current_uid()).err().unwrap();

        assert_eq!(error.kind(), io::ErrorKind::PermissionDenied);
        assert!(
            error.to_string().contains("not falling back to /tmp"),
            "{error}"
        );
        assert!(!base.exists());
    }

    #[test]
    fn a_symlinked_base_is_refused() {
        let target = fresh("basetarget");
        std::fs::create_dir(&target).unwrap();
        std::fs::set_permissions(&target, std::fs::Permissions::from_mode(0o700)).unwrap();
        let link = fresh("baselink");
        std::os::unix::fs::symlink(&target, &link).unwrap();
        let address = format!("{}/sub/core.sock", link.display());

        let error = prepare_in(&address, &link, current_uid()).err().unwrap();

        assert!(error.to_string().contains("symbolic link"), "{error}");
        assert!(entries(&target).is_empty());
        std::fs::remove_file(&link).unwrap();
        std::fs::remove_dir(&target).unwrap();
    }

    #[test]
    fn a_base_open_to_others_is_refused_and_kept() {
        let base = fresh("openbase");
        std::fs::create_dir(&base).unwrap();
        std::fs::set_permissions(&base, std::fs::Permissions::from_mode(0o755)).unwrap();
        let address = format!("{}/sub/core.sock", base.display());

        let error = prepare_in(&address, &base, current_uid()).err().unwrap();

        assert!(error.to_string().contains("open to other users"), "{error}");
        assert_eq!(
            std::fs::symlink_metadata(&base).unwrap().mode() & 0o7777,
            0o755
        );
        assert!(entries(&base).is_empty());
        std::fs::remove_dir(&base).unwrap();
    }

    #[test]
    fn a_socket_dir_outside_the_base_is_refused() {
        let base = user_temp_dir().unwrap();
        for address in [
            "/tmp/com.layoute.flash-501/core.sock".to_owned(),
            format!("{}/a/b/core.sock", base.display()),
            format!("{}/a/../b/core.sock", base.display()),
        ] {
            let error = prepare_in(&address, &base, current_uid()).err().unwrap();

            assert_eq!(error.kind(), io::ErrorKind::InvalidInput, "{address}");
            assert!(error.to_string().contains("not directly inside"), "{error}");
        }
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
