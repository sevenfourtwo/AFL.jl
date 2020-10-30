using AFL_jll, Clang_jll

Clang_jll.clang() do clang
	src = joinpath(@__DIR__, "afl-shim.c")
	out = joinpath(@__DIR__, "afl-shim")

	run(`$clang $src -o $out`)
end


AFL_jll.afl_clang_fast() do exe
	afl_path = joinpath(dirname(exe), "../lib/afl")
	afl_cc = Clang_jll.clang_path

	withenv("AFL_PATH" => afl_path, "AFL_CC" => afl_cc) do
		src = joinpath(@__DIR__, "afl-test.c")
		out = joinpath(@__DIR__, "afl-test")

		run(`$exe $src -o $out`)
	end
end
