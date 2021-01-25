using Test
using Cerberus
using SparseArrays
import Gurobi, MathOptInterface
const MOI = MathOptInterface

include("util.jl")
include("algorithm/util.jl")

const CONFIG = Cerberus.AlgorithmConfig(silent = true)
const GRB_ENV = isdefined(Main, :GRB_ENV) ? Main.GRB_ENV : Gurobi.Env()

for (root, dirs, files) in walkdir(@__DIR__)
    for _file in filter(f -> endswith(f, ".jl"), files)
        file = relpath(joinpath(root, _file), @__DIR__)
        if file in ["runtests.jl", "util.jl", "MOI_wrapper.jl"]
            continue
        end

        @testset "$(file)" begin
            include(file)
        end
    end
end
