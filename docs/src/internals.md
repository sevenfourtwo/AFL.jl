# Internals

This is a description of several implementation details. See also the [`techincal_details.txt`](https://github.com/google/AFL/blob/master/docs/technical_details.txt) file in the AFL repository for more information.

## Shared Memory Segment

The shared memory segment is used as an IPC mechanism to retrieve information about the coverage from the target process. The memory segment is used as a vector of 65536 (1024*64) UInt8's. The id of and a pointer to the memory segment are part of the [`Target`](@ref AFL.Target) struct.

## Coverage

Coverage is monitored inside the target program, the code responsible for this is compiled into the target by the `afl-gcc` and `afl-as` programs. Every time the program counter reaches a new basis block a byte is incremented in the shared memory segment, the index of of the byte increment is depending on the basic block to be executed and the previous executed block.

The coverage data can be read in julia and converted to a [`CoverageMap`](@ref AFL.CoverageMap). In this coverage map the counts are convered to bytes with zero or one high bits, representing a class of counts. The byte values corresponding to counts can be viewed in the following table.

Byte | Count
:--- | ----:
0x00 | 0
0x01 | 1
0x02 | 2
0x04 | 3
0x08 | 4-7
0x10 | 8-15
0x20 | 16-31
0x40 | 32-127
0x80 | 128-255

## Shim

The shim (see `deps/afl-shim.c`) is used a as a stub to start the actual program under test. It's tasks are:

1. Set the resource limits for the program
2. Duplicate stdin to fd 198 and stdout to 199, these fds will be used by the AFL forkserver to communicate with AFL.jl
3. The input file will be openend and it's fd duplicated to stdin
4. Stdout and stderr will be redirected to /dev/null
5. Finally an execv call will be made to start the real target program

## Forkserver

Now that the real target is running it will first execute the AFL forkserver (not part of AFL.jl), this code will do the following:

1. Check if fd 198 and 199 are open
2. Attach the shared memory segment (reading it's id from environment variable __AFL_SHM_ID)
3. Send a four byte hello message over the status socket (fd 199)
4. Wait for a four byte start message on the control socket (fd 198)
5. Fork (the chilld process will hand over execution to the actual program under test)
6. Send the pid of the child over the status socket
7. Wait until the child terminates and send the exitcode over the status socket, continue with step 4