# AFL.jl

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://sevenfourtwo.github.io/AFL.jl/dev)
[![Build Status](https://github.com/sevenfourtwo/AFL.jl/workflows/CI/badge.svg)](https://github.com/sevenfourtwo/AFL.jl/actions)

This package provides an interface to use the binary instrumentation logic from the [American Fuzzy Lop (AFL)](https://github.com/google/AFL) fuzzer in Julia. No fuzzing algorithm is implemented in this package, it serves merely as a starting point to do so. Technical details of te instrumentation logic from AFL can be found [here](https://github.com/google/AFL/blob/master/docs/technical_details.txt). The code in this packages borrows heavily from the [afl-fuzz](https://github.com/google/AFL/blob/master/afl-fuzz.c) program. Both source code based fuzzing and QEMU mode are supported.

At this point it implements only the minimal code to get instrumentation working. To handle some of the forkserver logic a simple C shim is build as a dependency (see `deps/afl-shim.c`).

## Installation

This package is not available in the in Julia registry yet. For now, it can be installed with the following command in the REPL:

```julia
] add https://github.com/sevenfourtwo/AFL.jl https://github.com/sevenfourtwo/AFL_jll.jl 
```

GCC is required to compile the loading shim.

## Example

See the [documentation](https://sevenfourtwo.github.io/AFL.jl/dev) for a simple example. 