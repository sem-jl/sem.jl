using SparseArrays, LinearAlgebra, BenchmarkTools, MKL

A = rand(200,200)
B = rand(200,200)

C = zeros(200,200)
C[3, 6] = 1
C[4, 6] = 1
C[31, 16] = 1
C[32, 56] = 1
C[43, 46] = 1
C[109, 89] = 1

ind = findall(x -> isone(x), C)

### BLAS
function genmul(A, C, B)
    D = A*C*B
    return D
end

@benchmark genmul(A, C, B)

C = sparse(C)

### SPARSE
@benchmark genmul(A, C, B)


### LOOP, column layout, without boradcasting, with @inbounds
B_2 = permutedims(B)

function outer_mul_4(A, B, ind)
    C = zeros(size(A))
    @inbounds for i in 1:length(ind)
        C += A[:, ind[i][1]]*B[:, ind[i][2]]'
    end
    return C
end

@benchmark outer_mul_4(A,B_2, ind)

### call BLAS directly
function outer_mul_5(A, B, ind)
    C = zeros(size(A))
    for i in 1:length(ind)
        BLAS.ger!(1.0, A[:, ind[i][1]], B[:, ind[i][2]], C)
    end
    return C
end

@benchmark outer_mul_5(A,B_2, ind)

### call BLAS directly, witout column mayor --> WINNER!!!
function outer_mul_7(A, B, ind)
    C = zeros(size(A))
    for i in 1:length(ind)
        BLAS.ger!(1.0, A[:, ind[i][1]], B[ind[i][2], :], C)
    end
    return C
end

@benchmark outer_mul_7(A,B, ind)

### with mul!
C = Matrix(C)

function outer_mul_6(A, B, C)
    D = similar(A)
    E = similar(C)
    mul!(D, A, C)
    mul!(E, D, B)
    return E
end

@benchmark outer_mul_6(A,B, C)


###################################
using SparseArrays, LinearAlgebra, BenchmarkTools, MKL

A = rand(100,100)
m = zeros(100)
m[10] = 1.0
m[56] = 1.0
m[84] = 1.0

A*m

C = similar(m)

ind = findall(x -> isone(x), m)

function sparse_outer_mul!(A, C,ind) #computes A*S*B -> C, where ind gives the entries of S that are 1
    C = zeros(size(A, 1))
    @views @inbounds for i in 1:length(ind)
        C += A[:, ind[i]]
    end
    return C
end

isapprox(A*m, sparse_outer_mul!(A, ind))

@benchmark A*m

@benchmark sparse_outer_mul!(A, ind)

function sparse_outer_mul_2!(A, ind) #computes FB*∇m, where ind gives the entries of S that are 1
    @views C = sum(A[:, ind], dims = 2)
    return C
end

isapprox(A*m, sparse_outer_mul_2!(A, ind))

@benchmark @views sum(A[:, ind], dims = 2)

@benchmark sparse_outer_mul_2!(A, ind)
@benchmark sparse_outer_mul_2!(C, A, ind)



###################################
using SparseArrays, LinearAlgebra, BenchmarkTools, MKL

A = rand(100,120)
S = zeros(120,120)
B = rand(120)

S[3, 6] = 1
S[4, 6] = 1
S[31, 16] = 1
S[32, 56] = 1
S[43, 46] = 1
S[109, 89] = 1

A*S*B

C = Vector{Float64}(undef, 100)

ind = findall(x -> isone(x), S)

function sparse_outer_mul!(C, A, B, ind) #computes A*S*B -> C, where ind gives the entries of S that are 1
    fill!(C, 0.0)
    @views @inbounds for i in 1:length(ind)
        BLAS.axpy!(B[ind[i][2]], A[:, ind[i][1]], C)
    end
end

sparse_outer_mul!(C, A, B, ind)

isapprox(A*S*B, C)

@benchmark genmul($A,$S,$B)

@benchmark sparse_outer_mul!(C, A, B, ind)

function sparse_outer_mul_2!(C, A, B::Vector, ind) #computes A*S*B -> C, where ind gives the entries of S that are 1
    fill!(C, 0.0)
    @views @inbounds for i in 1:length(ind)
        C .+= B[ind[i][2]].*A[:, ind[i][1]]
    end
end

sparse_outer_mul_2!(C, A, B, ind)

isapprox(A*S*B, C)

@benchmark sparse_outer_mul_2!(C, A, B, ind)