const _SUPPORTED_SETS = Union{MOI.LessThan,MOI.GreaterThan,MOI.EqualTo}

struct Polyhedron
    aff_constrs::Vector{Tuple{MOI.ScalarAffineFunction,<:_SUPPORTED_SETS}}
    # lt_constrs::Vector{Tuple{MOI.ScalarAffineFunction,MOI.LessThan}}
    # gt_constrs::Vector{Tuple{MOI.ScalarAffineFunction,MOI.GreaterThan}}
    # eq_constrs::Vector{Tuple{MOI.ScalarAffineFunction,MOI.EqualTo}}
    bounds::Vector{MOI.Interval}
    # TODO: Enforce that all bounds are finite.
    # TODO: Enforce that length(bound) is no less than max variable index
    #       appearing in aff_constrs.
end

# Assumption: Problem is being minimized
struct LPRelaxation
    feasible_region::Polyhedron
    obj::MOI.ScalarAffineFunction
end

struct Disjunction
    disjuncts::Vector{Polyhedron}
end

abstract type AbstractFormulater end

struct DMIPFormulation
    base_form::LPRelaxation
    disjunction_formulaters::Vector{AbstractFormulater}
    integrality::Vector{Tuple{MOI.SingleVariable,MOI.ZeroOne}}
end
