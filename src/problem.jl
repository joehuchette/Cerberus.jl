struct VariableIndex
    _value::Int
end
const CVI = VariableIndex
index(cvi::CVI) = cvi._value

struct ScalarAffineFunction
    coeffs::Vector{Float64}
    indices::Vector{CVI}
    constant::Float64

    function ScalarAffineFunction(
        coeffs::Vector{Float64},
        indices::Vector{CVI},
        constant::Float64,
    )
        @assert length(coeffs) == length(indices)
        return new(coeffs, indices, constant)
    end
end
const CSAF = ScalarAffineFunction
CSAF() = CSAF(Float64[], CVI[], 0.0)

# TODO: Unit test
function Base.convert(::Type{CSAF}, saf::SAF)
    return CSAF(
        [term.coefficient for term in saf.terms],
        [CVI(term.variable_index.value) for term in saf.terms],
        saf.constant,
    )
end
function Base.convert(::Type{CSAF}, sv::SV)
    return CSAF([1.0], [CVI(sv.variable.value)], 0.0)
end

"""
Internal representation for an affine constraint.
"""
struct AffineConstraint{S<:_C_SETS}
    f::CSAF
    s::S
end

function AffineConstraint(_f::SAF, _s::S) where {S<:_C_SETS}
    f, s = MOIU.normalize_constant(_f, _s)
    @assert f.constant == 0
    return AffineConstraint{S}(f, s)
end

# TODO: Unit test
"""
Compute the largest variable index in an affine expression (or constraint).
"""
_max_var_index(ac::AffineConstraint) = _max_var_index(ac.f)
function _max_var_index(csaf::CSAF)
    Base.isempty(csaf.coeffs) && return 0
    return maximum(index(cvi) for cvi in csaf.indices)
end

"""
Internal representation for a polyhedron. We disambiguate different signs in
the linear constraints for type stability reasons (in particular, for working
with bases). Variable bounds are also separately stored as intervals.

It is presumed that `length(bounds)` is equal to the number of variables (i.e.
the ambient dimension), and so the constraints may not contain an index greater
than this value.
"""
mutable struct Polyhedron
    lt_constrs::Vector{AffineConstraint{LT}}
    gt_constrs::Vector{AffineConstraint{GT}}
    et_constrs::Vector{AffineConstraint{ET}}
    bounds::Vector{IN}
    function Polyhedron(aff_constrs::Vector, bounds::Vector{IN})
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

"Query the ambient dimension (i.e. number of variables)."
ambient_dim(p::Polyhedron) = length(p.bounds)

"""
Increase the ambient dimension of a polyhedron by one. The new variable does
not have bounds, nor does it appear in any of the constraints.
"""
function add_variable(p::Polyhedron)
    push!(p.bounds, IN(-Inf, Inf))
    return nothing
end

# TODO: Unit test
"""
Add a single linear constraint to a polyhedron. The maximum variable index in
the constraint must be less than the ambient dimension of the polyhedron.
"""
function add_constraint(
    p::Polyhedron,
    aff_constr::AffineConstraint{S},
) where {S<:_C_SETS}
    n = ambient_dim(p)
    @assert _max_var_index(aff_constr) <= n
    if S == LT
        push!(p.lt_constrs, aff_constr)
    elseif S == GT
        push!(p.gt_constrs, aff_constr)
    else
        @assert S == ET
        push!(p.et_constrs, aff_constr)
    end
    return nothing
end

"""
Query a single linear constraint from a polyhedron. Returns the `i`-th affine
constraint with "sense" set `T` added to `p`.
"""
get_constraint(p::Polyhedron, T::Type{LT}, i::Int) = p.lt_constrs[i]
get_constraint(p::Polyhedron, T::Type{GT}, i::Int) = p.gt_constrs[i]
get_constraint(p::Polyhedron, T::Type{ET}, i::Int) = p.et_constrs[i]

"""
Reports the total number of linear constraints describing a polyhedron. Does
not count any bounds on the variables.
"""
function num_constraints(p::Polyhedron)
    return num_constraints(p, LT) +
           num_constraints(p, GT) +
           num_constraints(p, ET)
end
"""
Reports the number of linear constraints with "sense" set `T` describing a
polyhedron.
"""
num_constraints(p::Polyhedron, T::Type{LT}) = length(p.lt_constrs)
num_constraints(p::Polyhedron, T::Type{GT}) = length(p.gt_constrs)
num_constraints(p::Polyhedron, T::Type{ET}) = length(p.et_constrs)

# TODO: Unit test
"""
Returns `true` if the ambient dimension is 0 and there are no constraints,
and false otherwise.
"""
function Base.isempty(p::Polyhedron)
    return ambient_dim(p) == 0 &&
           num_constraints(p) == 0 &&
           Base.isempty(p.bounds)
end

abstract type AbstractFormulater end

mutable struct DMIPFormulation
    feasible_region::Polyhedron
    disjunction_formulaters::Vector{AbstractFormulater}
    variable_kind::Vector{_V_INT_SETS}
    obj::CSAF

    function DMIPFormulation(
        feasible_region::Polyhedron,
        disjunction_formulaters::Vector{AbstractFormulater},
        variable_kind::Vector,
        obj::CSAF,
    )
        n = ambient_dim(feasible_region)
        @assert length(variable_kind) == n
        @assert _max_var_index(obj) <= n
        return new(feasible_region, disjunction_formulaters, variable_kind, obj)
    end
end

function DMIPFormulation()
    return DMIPFormulation(
        Polyhedron(),
        AbstractFormulater[],
        _V_INT_SETS[],
        CSAF(),
    )
end

num_variables(fm::DMIPFormulation) = ambient_dim(fm.feasible_region)

function add_variable(fm::DMIPFormulation)
    add_variable(fm.feasible_region)
    push!(fm.variable_kind, nothing)
    return nothing
end

# TODO: Unit test
function Base.isempty(form::DMIPFormulation)
    return isempty(form.feasible_region) &&
           isempty(form.disjunction_formulaters) &&
           isempty(form.variable_kind) &&
           isempty(form.obj.indices) &&
           form.obj.constant == 0
end

# TODO: Unit test
function get_formulation_bounds(form::DMIPFormulation, cvi::CVI)
    bound = form.feasible_region.bounds[index(cvi)]
    l, u = bound.lower, bound.upper
    if form.variable_kind[index(cvi)] isa ZO
        l = max(0, l)
        u = min(1, u)
    end
    return l, u
end
