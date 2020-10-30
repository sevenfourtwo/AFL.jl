using AFL
using Test

@testset "AFL" begin
    @testset "run_target" begin
        target = AFL.init_target(joinpath(@__DIR__, "../deps/afl-test"))
        @test AFL.run_target(target, b"1234678") == AFL.Ok
    end
    
    @testset "run_target_qemu" begin
        target = AFL.init_target(joinpath(@__DIR__, "../deps/afl-shim"), qemu=true)
        @test AFL.run_target(target, b"") == AFL.Ok
    end

    @testset "close" begin
        target = AFL.init_target(joinpath(@__DIR__, "../deps/afl-test"))
        close(target)
    end
    
    @testset "has_new_bits_pos" begin
        virgin_bits = AFL.InvCoverageMap()
        trace_bits = AFL.CoverageMap()

        trace_bits.edges[3] = 0x1        
        @test AFL.has_new_coverage(virgin_bits, trace_bits) == true
        
        trace_bits.edges[3] = 0x8        
        @test AFL.has_new_coverage(virgin_bits, trace_bits) == true
    end

    @testset "has_new_bits_neg" begin
        virgin_bits = AFL.InvCoverageMap()
        trace_bits = AFL.CoverageMap()
        
        @test AFL.has_new_coverage(virgin_bits, trace_bits) == false

        virgin_bits.edges[2] = 0xFE
        @test AFL.has_new_coverage(virgin_bits, trace_bits) == false
        
        trace_bits.edges[2] = 0x1        
        @test AFL.has_new_coverage(virgin_bits, trace_bits) == false
    end
    
    @testset "has_new_bits_multiple" begin
        virgin_bits = AFL.InvCoverageMap()
        trace_bits = AFL.CoverageMap()

        virgin_bits.edges[3] = 0b11110101       
        trace_bits.edges[3]  = 0b00001101  

        @test AFL.has_new_coverage(virgin_bits, trace_bits) == true
    end

    @testset "mark_covered" begin
        virgin_bits = AFL.InvCoverageMap()
        trace_bits = AFL.CoverageMap()

        trace_bits.edges[3] = 0x1
        
        @test AFL.has_new_coverage(virgin_bits, trace_bits) == true

        AFL.mark_covered!(virgin_bits, trace_bits)

        @test AFL.has_new_coverage(virgin_bits, trace_bits) == false

        backup = copy(virgin_bits)
        AFL.mark_covered!(virgin_bits, trace_bits)

        @test virgin_bits == backup
    end

    @testset "deterministic" begin
        target = AFL.init_target(joinpath(@__DIR__, "../deps/afl-test"))

        AFL.run_target(target, b"12345678")
        cov1 = AFL.classify_coverage(target)

        AFL.run_target(target, b"12345678")
        cov2 = AFL.classify_coverage(target)

        @test cov1 == cov2
    end
    
    @testset "deterministic_qemu" begin
        target = AFL.init_target(joinpath(@__DIR__, "../deps/afl-shim"), qemu=true)

        AFL.run_target(target, b"12345678")
        cov1 = AFL.classify_coverage(target)

        AFL.run_target(target, b"12345678")
        cov2 = AFL.classify_coverage(target)

        @test cov1 == cov2
    end
end
