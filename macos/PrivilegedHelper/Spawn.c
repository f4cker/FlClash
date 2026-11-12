#include "Spawn.h"
#include <fcntl.h>
#include <grp.h>
#include <signal.h>
#include <sys/stat.h>
#include <unistd.h>

pid_t FCSpawnCore(const char *core, const char *socket, uid_t uid, gid_t gid) {
    if (uid == 0 || gid == (gid_t)-1) return -1;
    pid_t child = fork();
    if (child != 0) return child;
    umask(0077);
    if (chdir("/") || setgroups(1, &gid) || setgid(gid) || setreuid(uid, 0)) _exit(126);
    int nullfd = open("/dev/null", O_RDWR);
    if (nullfd < 0) _exit(126);
    for (int fd = 0; fd < 3; fd++) if (dup2(nullfd, fd) < 0) _exit(126);
    for (int fd = 3; fd < getdtablesize(); fd++) close(fd);
    sigset_t empty;
    sigemptyset(&empty);
    sigprocmask(SIG_SETMASK, &empty, NULL);
    signal(SIGTERM, SIG_DFL);
    signal(SIGINT, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);
    char *const argv[] = {(char *)core, (char *)socket, NULL};
    char *const env[] = {"PATH=/usr/bin:/bin", "HOME=/", "LANG=en_US.UTF-8", NULL};
    execve(core, argv, env);
    _exit(127);
}
