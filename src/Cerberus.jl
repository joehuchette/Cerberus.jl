module Cerberus

import DataStructures, Gurobi, MathOptInterface, SparseArrays, TimerOutputs
const MOI = MathOptInterface
const MOIU = MOI.Utilities

const VI = MOI.VariableIndex
const SV = MOI.SingleVariable
const SAF = MOI.ScalarAffineFunction{Float64}
const ET = MOI.EqualTo{Float64}
const GT = MOI.GreaterThan{Float64}
const LT = MOI.LessThan{Float64}
const IN = MOI.Interval{Float64}
const CI = MOI.ConstraintIndex
const ZO = MOI.ZeroOne
const GI = MOI.Integer

const _C_SETS = Union{ET,GT,LT}
const _O_FUNCS = Union{SV,SAF}
const _V_BOUND_SETS = Union{ET,GT,LT,IN}
const _V_INT_SETS = Union{Nothing,ZO,GI}

include("problem.jl")
include("tree.jl")

include("algorithm/config.jl")
include("algorithm/algorithm_state.jl")
include("algorithm/results.jl")
include("algorithm/lp_model.jl")
include("algorithm/util.jl")
include("algorithm/branch_and_bound.jl")
include("algorithm/branching.jl")

include("MOI/optimizer.jl")
include("MOI/variable.jl")
include("MOI/objective.jl")
include("MOI/linear_constraint.jl")
include("MOI/disjunctive_constraint.jl")
include("MOI/solution.jl")

end # module
