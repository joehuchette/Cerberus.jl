struct AffineConstraint{S <: _C_SETS}
    f::SAF
    s::S
end

# TODO: Unit test
function _max_var_index(saf::SAF)
    Base.isempty(saf.terms) && return 0
    return maximum(vi.variable_index.value for vi in saf.terms)
end
_max_var_index(ac::AffineConstraint) = _max_var_index(ac.f)

mutable struct Polyhedron
    lt_constrs::Vector{AffineConstraint{LT}}
    gt_constrs::Vector{AffineConstraint{GT}}
    et_constrs::Vector{AffineConstraint{ET}}
    bounds::Vector{IN}
    function Polyhedron(
        aff_constrs::Vector,
        bounds::Vector{IN},
    )
        n = length(bounds)
        p = new([], [], [], bounds)
        for aff_constr in aff_constrs
            @assert _max_var_index(aff_constr) <= n
            add_constraint(p, aff_constr)
        end
        return p
    end
end

function Polyhedron()
    return Polyhedron(AffineConstraint[], IN[])
end

ambient_dim(p::Polyhedron) = length(p.bounds)
function add_variable(p::Polyhedron)
    push!(p.bounds, IN(-Inf, Inf))
    return nothing
end

# TODO: Unit test
function add_constraint(p::Polyhedron, aff_constr::AffineConstraint{S}) where {S <: _C_SETS}
    if S == LT
        push!(p.lt_constrs, aff_constr)
    elseif S == GT
        push!(p.gt_constrs, aff_constr)
    else
        @assert S == ET
        push!(p.et_constrs, aff_constr)
    end
    nothing
end

get_constraint(p::Polyhedron, T::Type{LT}, i::Int) = p.lt_constrs[i]
get_constraint(p::Polyhedron, T::Type{GT}, i::Int) = p.gt_constrs[i]
get_constraint(p::Polyhedron, T::Type{ET}, i::Int) = p.et_constrs[i]

num_constraints(p::Polyhedron) = num_constraints(p, LT) + num_constraints(p, GT) + num_constraints(p, ET)
num_constraints(p::Polyhedron, T::Type{LT}) = length(p.lt_constrs)
num_constraints(p::Polyhedron, T::Type{GT}) = length(p.gt_constrs)
num_constraints(p::Polyhedron, T::Type{ET}) = length(p.et_constrs)

# TODO: Unit test
function Base.isempty(p::Polyhedron)
    return ambient_dim(p) == 0 &&
           num_constraints(p) == 0 &&
           Base.isempty(p.bounds)
end

# Assumption: objective sense == MINIMIZE
mutable struct LPRelaxation
    feasible_region::Polyhedron
    obj::SAF

    function LPRelaxation(feasible_region::Polyhedron, obj::SAF)
        n = ambient_dim(feasible_region)
        @assert _max_var_index(obj) <= n
        return new(feasible_region, obj)
    end
    # TODO: Check that obj does not go out of index w.r.t. feasible_region size.
end

function LPRelaxation()
    return LPRelaxation(Polyhedron(), convert(SAF, 0.0))
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
    integrality::Vector{_V_INT_SETS}

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
    return DMIPFormulation(LPRelaxation(), AbstractFormulater[], _V_INT_SETS[])
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
