module Cerberus

import DataStructures,
    DisjunctiveConstraints,
    Gurobi,
    Logging,
    MathOptInterface,
    Printf,
    SparseArrays
const MOI = MathOptInterface
const MOIU = MOI.Utilities

const VI = MOI.VariableIndex
const SV = MOI.SingleVariable
const VOV = MOI.VectorOfVariables
const SAT = MOI.ScalarAffineTerm{Float64}
const SAF = MOI.ScalarAffineFunction{Float64}
const VAT = MOI.VectorAffineTerm{Float64}
const VAF = MOI.VectorAffineFunction{Float64}
const ET = MOI.EqualTo{Float64}
const GT = MOI.GreaterThan{Float64}
const LT = MOI.LessThan{Float64}
const IN = MOI.Interval{Float64}
const CI = MOI.ConstraintIndex
const ZO = MOI.ZeroOne
const GI = MOI.Integer

"Sets allowed in linear constraints."
const _C_SETS = Union{ET,GT,LT}

"Allowed objective types."
const _O_FUNCS = Union{SV,SAF}

"Sets allowed as variable bounds."
const _V_BOUND_SETS = Union{ET,GT,LT,IN}

"Integrality sets allowed."
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
include("algorithm/logging.jl")

include("algorithm/formulaters/disjunctive_formulaters.jl")
include("algorithm/formulaters/naive_big_m.jl")

include("MOI/optimizer.jl")
include("MOI/variable.jl")
include("MOI/objective.jl")
include("MOI/linear_constraint.jl")
include("MOI/disjunctive_constraint.jl")
include("MOI/solution.jl")

end # module
