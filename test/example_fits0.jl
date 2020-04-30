include("../test/example_models0.jl");

using BenchmarkTools, Test

datas = (one_fact_dat, three_mean_dat, three_path_dat)

start_values = (
    vcat(fill(1, 4), fill(0.5, 2)),
    vcat(fill(1, 9), fill(1, 3), fill(0.5, 3), fill(0.5, 6), vec(mean(convert(Matrix{Float64}, three_mean_dat), dims = 1))),
    vcat(fill(1.0, 11), fill(0.05, 3), fill(0.0, 6), fill(1.0, 8), fill(0, 3))
    )


### model 1

test = sem.model(one_fact_ram, datas[1], start_values[1])

@benchmark fit(test)

# compare parameters
pars = Optim.minimizer(fit(test))
par_order = [collect(4:7); collect(2:3)]

@test all(abs.(pars .- one_fact_par.est[par_order]) .< 0.02)


### model 2
three_mean_ram = ram(S, F, A, M, start_val,
    zeros(9,9))

test = sem.model(three_mean_ram,
                datas[2],
                start_values[2])


@benchmark fit(test)

pars = Optim.minimizer(fit(test))
par_order = [collect(19:33); 2;3;5;6;8;9; collect(10:18)]

@test all(abs.(pars .- three_mean_par.est[par_order]) .< 0.02)

@benchmark test.objective(convert(Array{ForwardDiff.Dual{Nothing, Float64, 0}}, test.par),
    test)

test.ram = nothing

function imp_cov(ram::ram)
    #invia = similar(ram.A)
    invia = inv(I - ram.A)
    #invia .= LinearAlgebra.inv!(factorize(I - ram.A))
    ram.imp_cov .= ram.F*invia*ram.S*transpose(invia)*transpose(ram.F)
end


imp_cov(three_mean_ram)

@code_warntype test.objective(start_values[2], test)

test

@time test.ram(start_values[2])

### model 3

using LinearAlgebra

three_path_ram = ram(S, F, A, nothing, start_val_path,
    zeros(11,11))

test = sem.model(three_path_ram,
                datas[3],
                start_val_path)

#start_values[3][collect(1:11)] .= diag(test.obs.cov)

#start_values[3][collect(12:14)] .= 0.0

#pars = Optim.minimizer(fit(test))

par_order = [collect(21:34);  collect(15:20); 2;3; 5;6;7; collect(9:14)]

@test all(abs.(pars .- three_path_par.est[par_order]) .< 0.02*abs.(pars))

fit(test)

test.objective(three_path_par.est[par_order], test)

lav_start_par.est[par_order]

using LineSearches

optimize(
    par -> test.objective(par, test),
    lav_start_par.est[par_order],
    LBFGS(),
    autodiff = :forward,
    Optim.Options(allow_f_increases = false#,
                    #x_tol = 1e-4,
                    #f_tol = 1e-4
                    ))

function func(invia, D)
      imp = D[2]*invia*D[1]*transpose(invia)*transpose(D[2])
      return imp
end



par = Feather.read("test/comparisons/three_mean_par.feather")

test.objective(start_values[2], test)

### minimal working example
using Optim, ForwardDiff

### old solution

function mymatrix(par)
    A =    [0 0 0 0 0 0 0 0
            0 0 0 0 0 0 0 0
            0 0 0 0 0 0 0 0
            0 0 0 0 0 0 0 par[1]]
    return A
end

function old_objective(par, func)
    A = func(par)
    return A[4,8]^2
end

@benchmark optimize(par -> old_objective(par, mymatrix),
            [5.0],
            LBFGS(),
            autodiff = :forward)

### gives an error

mutable struct MyStruct{T}
    a::T
end

A =  [0.0 0 0 0 0 0 0 0
        0 0 0 0 0 0 0 0
        0 0 0 0 0 0 0 0
        0 0 0 0 0 0 0 0]

function MyStruct(A)
    optimize(par -> wrap(par, teststruct),
                [5.0],
                LBFGS(),
                autodiff = :forward)

teststruct = MyStruct(A)

function prepare_struct(par, mystruct)
    mystruct.a[4,8] = par[1]
    return mystruct
end

function objective(mystruct)
    mystruct.a[4,8]^2
end

function wrap(par, mystruct)
    mystruct = prepare_struct(par, mystruct)
    return objective(mystruct)
end

optimize(par -> wrap(par, teststruct),
            [5.0],
            LBFGS(),
            autodiff = :forward)

### working solution

function myconvert(par, mystruct)
    T = eltype(par)
    new_array = convert(Array{T}, mystruct.a)
    mystruct_conv = MyStruct(new_array)
    return mystruct_conv
end

function new_wrap(par, mystruct)
    mystruct = myconvert(par, mystruct)
    mystruct = prepare_struct(par, mystruct)
    return objective(mystruct)
end

@benchmark optimize(par -> new_wrap(par, teststruct),
            [5.0],
            LBFGS(),
            autodiff = :forward)

### solutin with diffeq
using Optim, OrdinaryDiffEq, LinearAlgebra
using DiffEqBase, ForwardDiff

mutable struct MyStruct{T}
    a::T
end

A =  [0 0
    0 3.0]

teststruct = MyStruct(A)

function wrap(par, matr)
    matr = DiffEqBase.get_tmp(matr, par)
    matr[1,1] = par[1]
    print(matr)
    return matr[1,1]^2
end

wrap([ForwardDiff.Dual(1)],
    teststruct.a, DiffEqBase.dualcache(teststruct.a))

optimize(par -> wrap(par, DiffEqBase.dualcache(A)),
            [5.0],
            LBFGS(),
            autodiff = :forward)


function foo(du, u, (A, tmp))
    tmp = DiffEqBase.get_tmp(tmp, u)
    mul!(tmp, A, u)
    @. du = u + tmp
    nothing
end

foo(ones(5, 5), (0., 1.0),
        (ones(5,5), DiffEqBase.dualcache(zeros(5,5))))
solve(prob, TRBDF2())


A = rand(10, 10)

par = zeros(3)