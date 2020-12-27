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
const INT = MOI.Interval{Float64}
const CI = MOI.ConstraintIndex

const _SUPPORTED_SETS = Union{MOI.LessThan,MOI.GreaterThan,MOI.EqualTo}
const _INT_SETS = Union{Nothing,MOI.ZeroOne,MOI.Integer}
const _C_SETS = Union{ET,GT,LT}
const _O_FUNCS = Union{SV,SAF}
const _V_SETS = Union{ET,GT,LT,INT}

include("problem.jl")
include("tree.jl")

include("algorithm/config.jl")
include("algorithm/algorithm_state.jl")
include("algorithm/results.jl")
include("algorithm/lp_model.jl")
include("algorithm/util.jl")
include("algorithm/branch_and_bound.jl")
include("algorithm/branching.jl")

include("MOI/MOI_wrapper.jl")

end # module
