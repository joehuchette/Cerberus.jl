const _SUPPORTED_SETS = Union{MOI.LessThan,MOI.GreaterThan,MOI.EqualTo}

struct AffineConstraint
    f::MOI.ScalarAffineFunction{Float64}
    s::_SUPPORTED_SETS
end

# TODO: Unit test
function _max_var_index(saf::MOI.ScalarAffineFunction{Float64})
    Base.isempty(saf.terms) && return 0
    return maximum(vi.variable_index.value for vi in saf.terms)
end
_max_var_index(ac::AffineConstraint) = _max_var_index(ac.f)

mutable struct Polyhedron
    aff_constrs::Vector{AffineConstraint}
    l::Vector{Float64}
    u::Vector{Float64}
    # TODO: Enforce that all bounds are finite.
    # TODO: Enforce that length(bound) is no less than max variable index
    #       appearing in aff_constrs.
    function Polyhedron(
        aff_constrs::Vector{AffineConstraint},
        l::Vector{Float64},
        u::Vector{Float64},
    )
        n = length(l)
        @assert n == length(u)
        for aff_constr in aff_constrs
            @assert _max_var_index(aff_constr) <= n
        end
        return new(aff_constrs, l, u)
    end
end

function Polyhedron()
    return Polyhedron(AffineConstraint[], Float64[], Float64[])
end

ambient_dim(p::Polyhedron) = length(p.l)
function add_variable(p::Polyhedron)
    push!(p.l, -Inf)
    push!(p.u, Inf)
    return nothing
end

num_constraints(p::Polyhedron) = length(p.aff_constrs)

# TODO: Unit test
function Base.isempty(p::Polyhedron)
    return ambient_dim(p) == 0 &&
           num_constraints(p) == 0 &&
           Base.isempty(p.l) &&
           Base.isempty(p.u)
end

# Assumption: objective sense == MINIMIZE
mutable struct LPRelaxation
    feasible_region::Polyhedron
    obj::MOI.ScalarAffineFunction{Float64}

    function LPRelaxation(
        feasible_region::Polyhedron,
        obj::MOI.ScalarAffineFunction{Float64},
    )
        n = ambient_dim(feasible_region)
        for aff_constr in feasible_region.aff_constrs
            @assert _max_var_index(aff_constr) <= n
        end
        @assert _max_var_index(obj) <= n
        return new(feasible_region, obj)
    end
    # TODO: Check that obj does not go out of index w.r.t. feasible_region size.
end

function LPRelaxation()
    return LPRelaxation(
        Polyhedron(),
        convert(MOI.ScalarAffineFunction{Float64}, 0.0),
        # MOI.ScalarAffineFunction{Float64}(
        #     MOI.ScalarAffineTerm{Float64}[],
        #     0.0
        # ),
    )
end

num_variables(r::LPRelaxation) = ambient_dim(r.feasible_region)

# TODO: Unit test
function Base.isempty(r::LPRelaxation)
    return Base.isempty(r.feasible_region) &&
           Base.isempty(r.obj.terms) &&
           r.obj.constant == 0
end

struct Disjunction
    disjuncts::Vector{Polyhedron}
end

abstract type AbstractFormulater end

mutable struct DMIPFormulation
    base_form::LPRelaxation
    disjunction_formulaters::Vector{AbstractFormulater}
    integrality::Vector{MOI.VariableIndex}

    function DMIPFormulation(
        base_form::LPRelaxation,
        disjunction_formulaters::Vector{AbstractFormulater},
        integrality::Vector{MOI.VariableIndex},
    )
        n = ambient_dim(base_form.feasible_region)
        for vi in integrality
            @assert vi.value <= n
        end
        return new(base_form, disjunction_formulaters, integrality)
    end
end

function DMIPFormulation()
    return DMIPFormulation(
        LPRelaxation(),
        AbstractFormulater[],
        MOI.VariableIndex[],
    )
end

num_variables(fm::DMIPFormulation) = num_variables(fm.base_form)

# TODO: Unit test
function Base.isempty(form::DMIPFormulation)
    return Base.isempty(form.base_form) &&
           Base.isempty(form.disjunction_formulaters) &&
           Base.isempty(form.integrality)
end
