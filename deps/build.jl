using AFLplusplus_jll
using CLang_jll

Clang_jll.clang() do clang
	src = joinpath(@__DIR__, "afl-shim.c")
	out = joinpath(@__DIR__, "afl-shim")

	run(`$clang $src -o $out`)

	AFLplusplus_jll.afl_clang_fast() do afl_clang
		afl_path = joinpath(dirname(afl_clang), "../lib/afl")
			
		src = joinpath(@__DIR__, "afl-test.c")
		out = joinpath(@__DIR__, "afl-test")

		withenv("AFL_PATH" => afl_path, "AFL_CC" => clang) do
			run(`$afl_clang $src -o $out`)
		end
	end
end