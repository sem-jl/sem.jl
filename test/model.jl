using sem, Feather, ModelingToolkit, Statistics, LinearAlgebra,
    Optim, SparseArrays, Test, Zygote, LineSearches, ForwardDiff

## Observed Data
three_path_dat = Feather.read("test/comparisons/three_path_dat.feather")
three_path_par = Feather.read("test/comparisons/three_path_par.feather")
three_path_start = Feather.read("test/comparisons/three_path_start.feather")

semobserved = SemObsCommon(data = Matrix(three_path_dat))

diff_fin = SemFiniteDiff(LBFGS(
        ;alphaguess = LineSearches.InitialStatic(;scaled = true),
        linesearch = LineSearches.Static()), Optim.Options(;g_tol = 0.001))
diff_fin = SemFiniteDiff(BFGS(), Optim.Options())
diff_for = SemForwardDiff(LBFGS(), Optim.Options())
diff_rev = SemReverseDiff(LBFGS(), Optim.Options())


## Model definition
@ModelingToolkit.variables x[1:31]

S =[x[1]  0     0     0     0     0     0     0     0     0     0     0     0     0
    0     x[2]  0     0     0     0     0     0     0     0     0     0     0     0
    0     0     x[3]  0     0     0     0     0     0     0     0     0     0     0
    0     0     0     x[4]  0     0     0     x[15] 0     0     0     0     0     0
    0     0     0     0     x[5]  0     x[16] 0     x[17] 0     0     0     0     0
    0     0     0     0     0     x[6]  0     0     0     x[18] 0     0     0     0
    0     0     0     0     x[16] 0     x[7]  0     0     0     x[19] 0     0     0
    0     0     0     x[15] 0     0     0     x[8]  0     0     0     0     0     0
    0     0     0     0     x[17] 0     0     0     x[9]  0     x[20] 0     0     0
    0     0     0     0     0     x[18] 0     0     0     x[10] 0     0     0     0
    0     0     0     0     0     0     x[19] 0     x[20] 0     x[11] 0     0     0
    0     0     0     0     0     0     0     0     0     0     0     x[12] 0     0
    0     0     0     0     0     0     0     0     0     0     0     0     x[13] 0
    0     0     0     0     0     0     0     0     0     0     0     0     0     x[14]]

F =[1.0 0 0 0 0 0 0 0 0 0 0 0 0 0
    0 1 0 0 0 0 0 0 0 0 0 0 0 0
    0 0 1 0 0 0 0 0 0 0 0 0 0 0
    0 0 0 1 0 0 0 0 0 0 0 0 0 0
    0 0 0 0 1 0 0 0 0 0 0 0 0 0
    0 0 0 0 0 1 0 0 0 0 0 0 0 0
    0 0 0 0 0 0 1 0 0 0 0 0 0 0
    0 0 0 0 0 0 0 1 0 0 0 0 0 0
    0 0 0 0 0 0 0 0 1 0 0 0 0 0
    0 0 0 0 0 0 0 0 0 1 0 0 0 0
    0 0 0 0 0 0 0 0 0 0 1 0 0 0]

A =[0  0  0  0  0  0  0  0  0  0  0     1     0     0
    0  0  0  0  0  0  0  0  0  0  0     x[21] 0     0
    0  0  0  0  0  0  0  0  0  0  0     x[22] 0     0
    0  0  0  0  0  0  0  0  0  0  0     0     1     0
    0  0  0  0  0  0  0  0  0  0  0     0     x[23] 0
    0  0  0  0  0  0  0  0  0  0  0     0     x[24] 0
    0  0  0  0  0  0  0  0  0  0  0     0     x[25] 0
    0  0  0  0  0  0  0  0  0  0  0     0     0     1
    0  0  0  0  0  0  0  0  0  0  0     0     0     x[26]
    0  0  0  0  0  0  0  0  0  0  0     0     0     x[27]
    0  0  0  0  0  0  0  0  0  0  0     0     0     x[28]
    0  0  0  0  0  0  0  0  0  0  0     0     0     0
    0  0  0  0  0  0  0  0  0  0  0     x[29] 0     0
    0  0  0  0  0  0  0  0  0  0  0     x[30] x[31] 0]


S = sparse(S)

#F
F = sparse(F)

#A
A = sparse(A)

start_val = vcat(
    vec(var(Matrix(three_path_dat), dims = 1))./2,
    fill(0.05, 3),
    fill(0.0, 6),
    fill(1.0, 8),
    fill(0, 3)
    )

loss = Loss([SemML(semobserved, [0.0], similar(start_val))])

imply = ImplySymbolic(A, S, F, x, start_val)

@benchmark ImplySymbolic(A, S, F, x, start_val)

imply_alloc = sem.ImplySymbolicAlloc(A, S, F, x, start_val)
#imply_forward = sem.ImplySymbolicForward(A, S, F, x, start_val)

model_fin = Sem(semobserved, imply, loss, diff_fin)
model_rev = Sem(semobserved, imply_alloc, loss, diff_rev)
#model_for = Sem(semobserved, imply_alloc, loss, diff_for)
#model_for2 = Sem(semobserved, imply_forward, loss, diff_for)
#model_ana = Sem(semobserved, imply, loss, diff_ana)

#Zygote.@nograd isposdef
#Zygote.@nograd Symmetric

solution_fin = sem_fit(model_fin)
#solution_for = sem_fit(model_for)
#solution_for2 = sem_fit(model_for2)
solution_rev = sem_fit(model_rev)
#solution_ana = sem_fit(model_ana)

par_order = [collect(21:34); collect(15:20); 2;3; 5;6;7; collect(9:14)]

all(
    abs.(solution_fin.minimizer .- three_path_par.est[par_order]
        ) .< 0.05*abs.(three_path_par.est[par_order]))

start_lav = three_path_start.start[par_order]

model_fin(start_val)
model_rev(start_val)

FiniteDiff.finite_difference_jacobian(model_rev, start_val) ==
    FiniteDiff.finite_difference_jacobian(model_fin, start_val)

truegrad = similar(start_val)
    
truegrad = FiniteDiff.finite_difference_jacobian(model_fin, start_val)

truegrad = [truegrad...]
const tape2 = 
    ReverseDiff.GradientTape(model_rev, (start_val))    
# compile `f_tape` into a more optimized representation
const compiled_tape2 = ReverseDiff.compile(tape2)

results = similar(start_val)
g_r(G, x) = ReverseDiff.gradient!(G, compiled_tape2, x)

truegrad .≈ results
##

g_f(x) = FiniteDiff.finite_difference_gradient(model_fin, x)

@benchmark model_fin(start_val)
@benchmark g_f(start_val)
@benchmark g_r(results, start_val)

solution = sem_fit(model_fin, g_f)
solution2 = sem_fit(model_fin)

solution.minimizer ≈ solution2.minimizer

solution3 = sem_fit(model_fin, g_r)

solution3.minimizer ≈ solution2.minimizer

@benchmark sem_fit(model_fin)
@benchmark sem_fit(model_fin, g_r)

const tape3 = 
    ReverseDiff.HessianTape(model_rev, (start_val))    
# compile `f_tape` into a more optimized representation
const compiled_tape3 = ReverseDiff.compile(tape3)

results = similar(start_val)
h_r(G, x) = ReverseDiff.hessian!(G, compiled_tape3, x)

@benchmark sem_fit(model_fin, g_r, h_r)

G = zeros(31,31)
@btime h_r(G, start_val)


using LinearAlgebra, Optim

obs = abs.(randn(20))

obs = obs*transpose(obs)

obs .= abs.(obs)

function myf(par, A)
    A[1] = par[1]
    A[2] = par[2]
    A[3] = par[3]
    A[4] = par[1]
    if !isposdef(A)
        return Inf
    else
        cholesky!(A)
        F = logdet(A) + tr(obs*inv(A))
    end
end

A = ones(2,2)

mysol = optimize(par -> myf(par, A), [2.4,2.05, 2.05],
    Optim.Options(show_trace=true, extended_trace = true))


A = [0 0 0 "c"
     1.0 0 0 .5
     0 0 0 0]

struct ImplySparse3{T1 <: AbstractSparseArray, T2 <: AbstractArray} <: Imply
    A::T1
    Aw::T2
end

function get_indices(A, func)
   permutedims(reinterpret(Int, reshape(findall(replace(func, A)), 1, :)))
end

function ImplySparse3(A)
    Aw = get_indices(A, x -> isa(x, String))
    ind = get_indices(A, x -> !(isa(x, Number) && iszero(x)))
    out = sparse(ind[:, 1], ind[:, 2], Vector{Float64}(undef, size(ind)[1]), size(A)...)
    for i in 1:size(ind)[1]
        probe = A[ind[i, 1], ind[i, 2]] # element of A
        if isa(probe, Number)
            out[ind[i, :]...] = probe
        end
    end
    ImplySparse3(out, Aw)
end

using StructuredOptimization

x = Variable(n)               # initialize optimization variable

λ = 1e-2*norm(A'*y, Inf)       # define λ

@minimize ls( A*x - y ) + λ*norm(x, 1)


##
using StructuredOptimization

n, m = 100, 10;                # define problem size

A, y = randn(m,n), randn(m);

x = StructuredOptimization.Variable(n)               # initialize optimization variable

λ = 1e-2*norm(A'*y, Inf)       # define λ

sol = @minimize ls( A*x - y ) #+ λ*norm(x, 1)

x = StructuredOptimization.Variable(31)

sol = @minimize model_for(x)
