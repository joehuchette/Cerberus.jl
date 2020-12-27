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
    bounds::Vector{MOI.Interval{Float64}}
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

function Polyhedron()
    return Polyhedron(AffineConstraint[], MOI.Interval{Float64}[])
end

ambient_dim(p::Polyhedron) = length(p.bounds)
function add_variable(p::Polyhedron)
    push!(p.bounds, MOI.Interval{Float64}(-Inf, Inf))
    return nothing
end

num_constraints(p::Polyhedron) = length(p.aff_constrs)

# TODO: Unit test
function Base.isempty(p::Polyhedron)
    return ambient_dim(p) == 0 &&
           num_constraints(p) == 0 &&
           Base.isempty(p.bounds)
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
    integrality::Vector{_INT_SETS}

    function DMIPFormulation(
        base_form::LPRelaxation,
        disjunction_formulaters::Vector{AbstractFormulater},
        integrality::Vector,
    )
        n = ambient_dim(base_form.feasible_region)
        @assert length(integrality) == n
        return new(base_form, disjunction_formulaters, integrality)
    end
end

function DMIPFormulation()
    return DMIPFormulation(
        LPRelaxation(),
        AbstractFormulater[],
        _INT_SETS[],
    )
end

num_variables(fm::DMIPFormulation) = num_variables(fm.base_form)

function add_variable(fm::DMIPFormulation)
    add_variable(fm.base_form.feasible_region)
    push!(fm.integrality, nothing)
    return nothing
end

# TODO: Unit test
function Base.isempty(form::DMIPFormulation)
    return Base.isempty(form.base_form) &&
           Base.isempty(form.disjunction_formulaters) &&
           Base.isempty(form.integrality)
end
