const _SUPPORTED_SETS = Union{MOI.LessThan,MOI.GreaterThan,MOI.EqualTo}

struct AffineConstraint
    f::MOI.ScalarAffineFunction{Float64}
    s::_SUPPORTED_SETS
end

function _max_var_index(saf::MOI.ScalarAffineFunction{Float64})
    return maximum(vi.variable_index.value for vi in saf.terms)
end
_max_var_index(ac::AffineConstraint) = _max_var_index(ac.f)

struct Polyhedron
    aff_constrs::Vector{AffineConstraint}
    bounds::Vector{MOI.Interval{Float64}}
    # TODO: Enforce that all bounds are finite.
    # TODO: Enforce that length(bound) is no less than max variable index
    #       appearing in aff_constrs.
    function Polyhedron(
        aff_constrs::Vector{AffineConstraint},
        bounds::Vector{MOI.Interval{Float64}}
    )
        n = length(bounds)
        for aff_constr in aff_constrs
            @assert _max_var_index(aff_constr) <= n
        end
        return new(aff_constrs, bounds)
    end
end

ambient_dim(p::Polyhedron) = length(p.bounds)

# Assumption: objective sense == MINIMIZE
struct LPRelaxation
    feasible_region::Polyhedron
    obj::MOI.ScalarAffineFunction{Float64}

    function LPRelaxation(feasible_region::Polyhedron, obj::MOI.ScalarAffineFunction{Float64})
        n = ambient_dim(feasible_region)
        for aff_constr in feasible_region.aff_constrs
            @assert _max_var_index(aff_constr) <= n
        end
        @assert _max_var_index(obj) <= n
        return new(feasible_region, obj)
    end
    # TODO: Check that obj does not go out of index w.r.t. feasible_region size.
end

num_variables(r::LPRelaxation) = length(r.feasible_region.bounds)

struct Disjunction
    disjuncts::Vector{Polyhedron}
end

abstract type AbstractFormulater end

struct DMIPFormulation
    base_form::LPRelaxation
    disjunction_formulaters::Vector{AbstractFormulater}
    integrality::Vector{MOI.VariableIndex}

    function DMIPFormulation(base_form::LPRelaxation, disjunction_formulaters::Vector{AbstractFormulater}, integrality::Vector{MOI.VariableIndex})
        n = ambient_dim(base_form.feasible_region)
        for vi in integrality
            @assert vi.value <= n
        end
        return new(base_form, disjunction_formulaters, integrality)
    end
end

num_variables(fm::DMIPFormulation) = num_variables(fm.base_form)

