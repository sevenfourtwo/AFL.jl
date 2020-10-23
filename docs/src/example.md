# Example

To use this package to instrument a program it needs te be compiled with the `afl-gcc` or `afl-clang` program which is part of AFL and can be installed on most Linux systems from the package manager (`afl++` on Ubuntu, `american-fuzzy-lop` on Fedora). The binary `AFL_jll` package does also ship a precompiled `afl-gcc`, its path can be retrieved in Julia as `AFL_jll.afl_gcc_exe_path`.

!!! note
    `AFL_jll` is based on [AFL++](https://github.com/AFLplusplus/AFLplusplus), but `AFL.jl` can handle both programs instrumented with the original AFL tools as well as the AFL++ tools.

Load the required packages (AFL_jll is a binary dependecy of AFL.jl, here it is explicitly required to access to test program):

```@repl example
using AFL, AFL_jll
```

For this example the AFL test program ([source](https://github.com/AFLplusplus/AFLplusplus/blob/2.68c/test-instr.c)) is used, a compiled version is shipped with the AFL_jll package. The target can be started from the Julia REPL:

```@repl example
target = init_target(AFL_jll.afl_test_instr_exe_path);
```

!!! note
    The test program does only work correctly on `i686` and `x86_64` systems.

We have created a [forkserver](@ref Forkserver) instance for our target. The forkserver is actually the target binary but it is still running the AFL trampoline code and waiting for a command. When this command is given the target will fork itself and the child will become the actual target. Communication with the forkserver and the actual target is implemented in this package.

Running the target with only zero bytes as input results in a clean execution as can be seen in the following example:

```@repl example
run_target(target, b"0")
```

Using the instrumentation tools we can see that several branches were covered with this input (the `classify_coverage` function convert the trace bit from the execution to a coverage map and the `coverage_stats` function returns the ratio of edges and classes covered by this input). The meaning of the edge classes can be found in the [coverage](@ref Coverage) section.

```@repl example
coverage = classify_coverage(target);
coverage_stats(coverage)
[i => class for (i, class) in enumerate(coverage.edges) if class > 0]
```

!!! warning
    The edge numbers are randomly generated every time the target program is compilated. Make sure you only compare those values in runs of the exact same target program.

By changing to input we can see the code takes some more branches, covering more code.

```@repl example
run_target(target, b"12345678")
coverage = classify_coverage(target);
coverage_stats(coverage)
[i => class for (i, class) in enumerate(coverage.edges) if class > 0]
```

When finished close the connection with the forkserver with:

```@repl example
close(target)
```