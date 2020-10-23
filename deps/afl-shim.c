#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/shm.h>
#include <sys/resource.h>

const int FORKSRV_CTL_FD = 198;
const int FORKSRV_ST_FD = 199;

int main(int argc, char** argv) {
    if(argc < 3) {
        fprintf(stderr, "Usage: %s input memlimit target [args...]\n", argv[0]);
        exit(1);
    }

    // open the input file and /dev/null
    int input_fd = open(argv[1], O_RDONLY);
    int devnull_fd = open("/dev/null", O_RDWR);

    // set memlimit in megabytes
    int memlimit = atoi(argv[2]) * 1024 * 1024;
    struct rlimit limits = { memlimit, memlimit};
    setrlimit(RLIMIT_AS, &limits);

    // copy stdin the forkserver control pipe and stdout to the status pipe
    dup2(0, FORKSRV_CTL_FD);
    dup2(1, FORKSRV_ST_FD);

    // set the input file as stdin and redirect stdout and stderr to /dev/null
    dup2(input_fd, 0);
    dup2(devnull_fd, 1);
    dup2(devnull_fd, 2);

    // close extra file descriptors
    close(input_fd);
    close(devnull_fd);

    // execute the real target
    execv(argv[3], argv + 3);

    // this code will only be reached if execv failed, to communicate the failure
    // a special signature will be set in shared memory region
    int id = atoi(getenv("__AFL_SHM_ID"));

    int* map = shmat(id, 0, 0);
    map[0] = 0xfee1dead;

    shmdt(map);
}