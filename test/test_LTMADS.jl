using Random
using LinearAlgebra

const DS = DirectSearch

@testset "LTMADS" begin
    all_in_range(l, arr, rng) = mapreduce(x -> x in rng, (x,y) -> x && y, arr)
    T = Float64
    #= Audet & Dennis 2006 pg. 203 generation of vector b(ℓ) =#
    @testset "b_l_generation" begin
        b = Dict(0.0 => [0.0, 1.0, 0.0])
        i = Dict(0.0 => 2)
        N = 3
        @test DS.b_l_generation(b,i,0.0,N) == (b[0.0],i[0.0])

        l = 1.0
        nb, ni = DS.b_l_generation(b,i,l,N)
        @test nb[ni] == 2.0 || nb[ni] == -2.0
        @test all_in_range(1.0, nb, -2^l:2^l)
    end

    #= Audet & Dennis 2006 pg. 203 generation of matrix L =#
    @testset "L_generation" begin
        l = 2.0
        N = 3
        mat = DS.L_generation(N, l)
        #Verify determinant
        @test abs(det(mat)) == 2^(l*(N-1))
        #Upper triangle is zero
        @test all([mat[i,j] == 0 for i=1:N-1, j=1:N-1 if i<j])
        #Lower triangle has all value in range -2ˡ+1:2ˡ-1
        @test all_in_range(l, [mat[i,j] for i=1:N-1, j=1:N-1 if i>j], -2^l+1:2^l-1)
        #Diagonal has all value equal to ±2ˡ
        @test all_in_range(l, [mat[i,j] for i=1:N-1, j=1:N-1 if i==j], [-2^l,2^l])
    end

    #= Audet & Dennis 2006 pg. 203 generation of matrix B =#
    @testset "B_generation" begin
        l = 3; N = 4
        L = DS.L_generation(N, l)
        b, I = DS.b_l_generation(Dict{Float64,Vector{Float64}}(), Dict{Float64,Int64}(), l, N)
        p = shuffle!(setdiff(1:N, I))
        
        B = DS.B_generation(N, I, b, L, perm=p)
        @test all([B[p[i],1:N-1] == L[i,:] for i=1:N-1])
        @test all(B[I, 1:N-1] .== 0 )
        @test B[:,N] == b
        @test abs(det(B)) == 2^(l * N)
    end

    @testset "Match_Example" begin
        b = [-3, 2, 4, -1, 0]
        I = 3
        L = [-4.0  0.0  0.0 0.0;
              3.0  4.0  0.0 0.0;
             -1.0  2.0 -4.0 0.0;
              1.0 -2.0  0.0 4.0]
        p = [4,1,2,5]
        q = [5,1,3,2,4]
        N = 5
        
        B = [ 3.0  4.0  0.0 0.0 -3.0;
             -1.0  2.0 -4.0 0.0  2.0;
              0.0  0.0  0.0 0.0  4.0;
             -4.0  0.0  0.0 0.0 -1.0;
              1.0 -2.0  0.0 4.0  0.0]
        _B = DS.B_generation(N, I, b, L, perm=p)
        @test _B == B

        B′ = [ 4.0 0.0  0.0 -3.0  3.0;
              2.0 0.0 -4.0  2.0 -1.0;
              0.0 0.0  0.0  4.0  0.0;
              0.0 0.0  0.0 -1.0 -4.0;
             -2.0 4.0  0.0  0.0  1.0]
        _B′ = DS.B′_generation(B, N, perm=q)
        @test _B′ == B′
        
        Dₖmin = [ 4.0 0.0  0.0 -3.0  3.0 -4.0;
                  2.0 0.0 -4.0  2.0 -1.0  1.0;
                  0.0 0.0  0.0  4.0  0.0 -4.0;
                  0.0 0.0  0.0 -1.0 -4.0  5.0;
                 -2.0 4.0  0.0  0.0  1.0 -3.0]
        @test Dₖmin == DS.form_basis_matrix(N, B′, false)

        Dₖmax = [ 4.0 0.0  0.0 -3.0  3.0 -4.0 -0.0 -0.0  3.0 -3.0;
                  2.0 0.0 -4.0  2.0 -1.0 -2.0 -0.0  4.0 -2.0  1.0;
                  0.0 0.0  0.0  4.0  0.0 -0.0 -0.0 -0.0 -4.0 -0.0;
                  0.0 0.0  0.0 -1.0 -4.0 -0.0 -0.0 -0.0  1.0  4.0;
                 -2.0 4.0  0.0  0.0  1.0  2.0 -4.0 -0.0 -0.0 -1.0]
        @test Dₖmax == DS.form_basis_matrix(N, B′, true)
    end

    @testset "LTMADS" begin
        LTM = DS.DSProblem{T}(3, poll=LTMADS{T}())
        @test !isdefined(LTM, :objective)
        @test isdefined(LTM, :constraints)
        @test LTM.sense == DS.Min
        @test LTM.N == 3
        @test LTM.status == DS.Unoptimized
    end

    @testset "MeshUpdate" begin
        p = DS.DSProblem{T}(3, poll=LTMADS{T}())
        @test p.mesh.Δᵐ == 1
        DS.MeshUpdate!(p, DS.Unsuccessful)
        @test p.mesh.Δᵐ == 1/4
        DS.MeshUpdate!(p, DS.Dominating)
        @test p.mesh.Δᵐ == 1
        DS.MeshUpdate!(p, DS.Improving)
        @test p.mesh.Δᵐ == 1
        DS.MeshUpdate!(p, DS.Dominating)
        @test p.mesh.Δᵐ == 1
        DS.MeshUpdate!(p, DS.Unsuccessful)
        DS.MeshUpdate!(p, DS.Unsuccessful)
        @test p.mesh.Δᵐ == 1/16
        DS.MeshUpdate!(p, DS.Improving)
        @test p.mesh.Δᵐ == 1/16
        DS.MeshUpdate!(p, DS.Dominating)
        @test p.mesh.Δᵐ == 1/4
    end
end