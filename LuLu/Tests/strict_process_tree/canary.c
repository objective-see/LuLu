// Local socket canary. No LuLu, proxy, or system configuration changes.
#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>

static int probe(const char* host, const char* port, const char* protocol)
{
    struct addrinfo hints = {0}, *address = NULL;
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = strcmp(protocol, "tcp") == 0 ? SOCK_STREAM : SOCK_DGRAM;
    hints.ai_flags = AI_NUMERICHOST | AI_NUMERICSERV;
    int success = 0, fd = -1, error = 0;
    if(getaddrinfo(host, port, &hints, &address) != 0) return 2;
    fd = socket(address->ai_family, address->ai_socktype, 0);
    if(fd < 0) goto done;
    fcntl(fd, F_SETFL, O_NONBLOCK);
    int connected = connect(fd, address->ai_addr, address->ai_addrlen);
    if(connected < 0 && errno != EINPROGRESS) goto done;
    struct pollfd wait = {fd, POLLOUT, 0};
    if(poll(&wait, 1, 1500) <= 0) goto done;
    socklen_t length = sizeof(error);
    if(getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &length) < 0 || error != 0) goto done;
    const char payload[] = "lulu-strict-canary";
    if(send(fd, payload, sizeof(payload), 0) != sizeof(payload)) goto done;
    wait.events = POLLIN;
    if(poll(&wait, 1, 1500) <= 0) goto done;
    char response[sizeof(payload)] = {0};
    ssize_t received = recv(fd, response, sizeof(response), 0);
    success = received == sizeof(payload) && memcmp(payload, response, sizeof(payload)) == 0;
done:
    if(fd >= 0) close(fd);
    freeaddrinfo(address);
    printf("{\"exchange\":%s,\"pid\":%d,\"ppid\":%d}\n", success ? "true" : "false", getpid(), getppid());
    fflush(stdout);
    return success ? 0 : 1;
}
int main(int argc, char** argv)
{
    if(argc == 5 && strcmp(argv[1], "probe") == 0) return probe(argv[2], argv[3], argv[4]);
    if(argc != 6) return 2;
    const char* mode = argv[1];
    if(strcmp(mode, "root") == 0) return probe(argv[3], argv[4], argv[5]);
    if(strcmp(mode, "exec") == 0)
    {
        execl(argv[2], argv[2], "probe", argv[3], argv[4], argv[5], NULL);
        return 2;
    }
    pid_t child = fork();
    if(child < 0) return 2;
    if(child == 0)
    {
        if(strcmp(mode, "orphan") == 0)
        {
            pid_t grandchild = fork();
            if(grandchild < 0) _exit(2);
            if(grandchild != 0) _exit(0);
            // Root waits for the intermediate exit, then exits before this probe starts.
            usleep(400000);
        }
        else if(strcmp(mode, "child") != 0) _exit(2);
        execl(argv[2], argv[2], "probe", argv[3], argv[4], argv[5], NULL);
        _exit(2);
    }
    int status = 0;
    if(waitpid(child, &status, 0) < 0) return 2;
    return WIFEXITED(status) ? WEXITSTATUS(status) : 2;
}
