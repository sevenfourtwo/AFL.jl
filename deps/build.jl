src = joinpath(@__DIR__, "afl-shim.c")
out = joinpath(@__DIR__, "afl-shim")

run(`gcc $src -o $out`)