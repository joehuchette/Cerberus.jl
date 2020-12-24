const VI = MOI.VariableIndex
const SV = MOI.SingleVariable
const SAF = MOI.ScalarAffineFunction{Float64}
const ET = MOI.EqualTo{Float64}
const GT = MOI.GreaterThan{Float64}
const LT = MOI.LessThan{Float64}
const INT = MOI.Interval{Float64}
const CI = MOI.ConstraintIndex

include("optimizer.jl")
include("variable.jl")
include("objective.jl")
include("linear_constraint.jl")
include("disjunctive_constraint.jl")
include("solution.jl")
