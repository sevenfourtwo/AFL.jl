module AFL

using AFL_jll

export init_target, 
       run_target, 
       classify_coverage, 
       classify_coverage!,
       coverage_stats,
       mark_covered!,
       has_new_coverage

const RPC_RM_ID = 0;
const IPC_CREAT = 0o1000;
const SHM_RW = 0o600;
const MAP_SIZE = 1024 * 64
const EXEC_FAIL_SIG = UInt8[0xad, 0xde, 0xe1, 0xfe]

const CLASS_LOOKUP = vcat(
    [0, 1, 2, 4],
    [8   for _ in     4:7],
    [16  for _ in    8:15],
    [32  for _ in   16:31],
    [64  for _ in  32:127],
    [128 for _ in 128:255]
)

"""
    Result

Enum representing the return state of the running the target with an input.
"""
@enum Result begin
    Ok=0 
    Crash=1 
    Timeout=2 
    Error=3
end

"""
    CoverageMap

An array of bytes used to describe the coverage an input generated. Each byte represents 
a specific edge between in the code that can be covered, each bit represents a classification 
of counts this edge was taken. 
"""
struct CoverageMap
    edges::Vector{UInt8}

    CoverageMap() = new(fill(0x00, MAP_SIZE))
    CoverageMap(edges) = new(edges)
end

Base.copy(src::CoverageMap) = CoverageMap(copy(src.edges))  
Base.:(==)(x::CoverageMap, y::CoverageMap) = x.edges == y.edges


"""
    InvCoverageMap

See [`CoverageMap`](@ref). This is an inverted version, which can be faster in some cases. Often used 
to describe edges and counts not covered yet.
"""
struct InvCoverageMap
    edges::Vector{UInt8}

    InvCoverageMap() = new(fill(0xFF, MAP_SIZE))
    InvCoverageMap(edges) = new(edges)
end

Base.copy(src::InvCoverageMap) = InvCoverageMap(copy(src.edges))  
Base.:(==)(x::InvCoverageMap, y::InvCoverageMap) = x.edges == y.edges

"""
    Target

Represents a running AFL forkserver and a shared memory segment for the branch bitmap. Create one with 
[`init_target`](@ref) and close the handle with `close`.
"""
struct Target
    handle::Base.Process
    shm_id::Int
    trace_bits::Vector{UInt8}
    input_io::IOStream
end


function Base.close(target::Target)
    # detach the shared memory segment used for the branch bitmap
    @ccall shmdt(target.trace_bits::Ptr{UInt8})::Int32
    @ccall shmctl(target.shm_id::Int, RPC_RM_ID::Int32, 0::Int32)::Int32

    # kill the forkserver
    kill(target.handle)
end


"""
    init_target(target_path::String; qemu=false, memlimit=200)

Start a forkserver for the given target.
"""
function init_target(target_path::String; qemu::Bool=false, memlimit::Int=200)
    isfile(target_path) || error("Target '$target_path' does not exist")

    # flags for the 64kb shared memory segment
    shmflags = IPC_CREAT + SHM_RW

    # create the shared memory segment
    shm_id = @ccall shmget(0::Int, MAP_SIZE::Int, shmflags::Int)::Int32
    if shm_id == -1
        error("Failed to initialise shared memory")
    end

    # and load it in the address space of the current process
    map_ptr = @ccall shmat(shm_id::Int, 0::Int, 0::Int)::Ptr{UInt8}
    if map_ptr == -1
        error("Failed to allocate shared memory")
    end

    # create a julia array covering the shared memory
    trace_bits = unsafe_wrap(Array, map_ptr, MAP_SIZE)

    # temporary file used for the input
    input_file, input_io = mktemp()

    # start the forkserver, passing the shared memory id as env variable
    env = Dict("__AFL_SHM_ID" => shm_id, "LD_BIND_NOW" => 1)
    shim = joinpath(@__DIR__, "../deps/afl-shim")

    # TODO: support cli args
    if qemu
        AFL_jll.afl_qemu_trace_x86_64_exe() do qemu_exe
            #qemu_path = AFL_jll.afl_qemu_trace_exe_path
            cmd = Cmd(`$shim $input_file $memlimit $qemu_exe $target_path`, env=env)
        end
    else
        cmd = Cmd(`$shim $input_file $memlimit $target_path`, env=env)
    end

    handle = open(cmd, write=true, read=true)

    # read the 4 byte hello message from the AFL trampoline
    res = read(handle, 4)
    if length(res) != 4
        error("Failed handshake with forkserver")
    end
    
    Target(handle, shm_id, trace_bits, input_io)
end


"""
    run_target(target::Target, input::Vector{UInt8}; timeout=1)

Run the target with the specified input. Times out after `timeout` seconds. Return value is a Result enum.
"""
function run_target(target::Target, input::Vector{UInt8}; timeout::Int=1)::Result
    # reset the branch bitmap
    fill!(target.trace_bits, 0)

    # write input to the temporary input file
    truncate(target.input_io, 0)
    #write(target.input_io, UInt32(length(input)))
    write(target.input_io, input)
    flush(target.input_io)

    # write 4 bytes to the forkserver to trigger a fork
    write(target.handle, Int32(0))

    # get the pid of the child from the forkserver
    pid = read(target.handle, Int32)
    if pid == 0
        error("Did not receive child pid from forkserver")
    end

    # setup timeout
    timed_out = false
    status = 0xFFFF0000

    timeout_task = @async begin
        sleep(timeout)

        if status == 0xFFFF0000
            timed_out = true
            run(pipeline(`kill -9 $pid`, stdout=devnull, stderr=devnull))
        end
    end

    # get the status of the child from the forkserver, this will not return 
    # until the target exits
    status = read(target.handle, UInt32)

    if ((status & 0x7f) + 1 >> 1) > 0
        signal = status & 0x7f
        
        # check if child timed out
        if signal == Base.SIGKILL && timed_out
            return Timeout
        end

        # check if the forkserver reported a failure
        if target.map[1:4] == EXEC_FAIL_SIG
            return Error
        end

        return Crash
    end

    Ok
end
run_target(target::Target, input::Base.CodeUnits{UInt8, String}; kws...) = run_target(target, Vector{UInt8}(input); kws...)


"""
    classify_coverage!(dst::CoverageMap, target::Target)

In place version of [`classify_coverage`](@ref).
"""
function classify_coverage!(dst::CoverageMap, target::Target)
    map!(dst.edges, target.trace_bits) do x 
        CLASS_LOOKUP[x+1]
    end
end


"""
    classify_coverage(target::Target)

Convert the trace bits in the shared memory segment of the target to a classified coverage map.
"""
function classify_coverage(target::Target)
    map(target.trace_bits) do x 
        CLASS_LOOKUP[x+1]
    end |> CoverageMap
end


"""
    edges_covered, classes_covered = coverage_stats(map::CoverageMap)
    edges_covered, classes_covered = coverage_stats(map::InvCoverageMap)

Calculate the ratio of edges and classes covered in the give coverage map. The maximum possible 
coverage (1024 * 64 edges covered) is represented as 1.0.
"""
function coverage_stats(map::CoverageMap)::Tuple{Float32, Float32}
    edgecount = 0
    classcount = 0

    for edge in map.edges
        if edge != 0x00
            edgecount += 1
            classcount += count_ones(edge)
        end
    end

    edgecount / MAP_SIZE, classcount / (MAP_SIZE * 8)
end


function coverage_stats(map::InvCoverageMap)::Tuple{Float32, Float32}
    edgecount = 0
    classcount = 0

    for edge in map.edges
        if edge != 0xFF
            edgecount += 1
            classcount += count_zeros(edge)
        end
    end

    edgecount / MAP_SIZE, classcount / (MAP_SIZE * 8)
end


"""
    mark_covered!(dst::InvCoverageMap, src::CoverageMap)

Marks the edges and classes covered by `src` as covered in `dst`.
"""
function mark_covered!(dst::InvCoverageMap, src::CoverageMap)
    dst.edges .&= .~(src.edges)
end


"""
    has_new_coverage(dst::InvCoverageMap, src::CoverageMap)

Compares `dst` with `src` and returns `true` when `src` covers edges or classes not yet 
marked as covered in `src`, otherwise returns `false`.
"""
function has_new_coverage(dst::InvCoverageMap, src::CoverageMap)::Bool
    any(x -> (x[1] & x[2]) != 0x0, zip(dst.edges, src.edges))
end


end # module