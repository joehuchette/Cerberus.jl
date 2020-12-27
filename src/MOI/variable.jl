function MOI.add_variable(opt::Optimizer)
    add_variable(opt.form)
    return MOI.VariableIndex(num_variables(opt.form.base_form))
end

function MOI.add_variables(opt::Optimizer, N::Int)
    return [MOI.add_variable(opt) for i in 1:N]
end

function MOI.is_valid(opt::Optimizer, v::VI)
    return 1 <= v.value <= num_variables(opt.form.base_form)
end

function MOI.get(opt::Optimizer, ::MOI.VariablePrimal, vi::MOI.VariableIndex)
    MOI.throw_if_not_valid(opt, vi)
    return opt.result.best_solution[vi]
end

function MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{<:_V_SETS})
    return true
end

# TODO: This might "lie" to you: For example, if you set
# both a GT and LT constraint, this will report it as an
# INT constraint.
function _get_scalar_set(p::Polyhedron, i::Int)
    bound = p.bounds[i]
    l, u = bound.lower, bound.upper
    if -Inf < l == u < Inf
        return ET
    elseif -Inf < l && u == Inf
        return GT
    elseif l == -Inf && u < Inf
        return LT
    elseif -Inf < l <= u < Inf
        return INT
    else
        @assert l == -Inf && u == Inf
        return nothing
    end
end

function MOI.is_valid(opt::Optimizer, c::CI{SV,S}) where {S <: _V_SETS}
    MOI.is_valid(opt, VI(c.value)) || return false
    p = opt.form.base_form.feasible_region
    return S == _get_scalar_set(p, c.value)
end

function MOI.get(opt::Optimizer, ::MOI.ConstraintFunction, c::CI{SV,<:_V_SETS})
    MOI.throw_if_not_valid(opt, c)
    return SV(VI(c.value))
end

# TODO: Do we need to throw if bounds are already set?
function MOI.add_constraint(opt::Optimizer, f::SV, s::ET)
    MOI.throw_if_not_valid(opt, f.variable)
    idx = f.variable.value
    opt.form.base_form.feasible_region.bounds[idx] = MOI.Interval{Float64}(s.value, s.value)
    return CI{SV,ET}(idx)
end
function MOI.add_constraint(opt::Optimizer, f::SV, s::GT)
    MOI.throw_if_not_valid(opt, f.variable)
    idx = f.variable.value
    prev_int = opt.form.base_form.feasible_region.bounds[idx]
    opt.form.base_form.feasible_region.bounds[idx] = MOI.Interval{Float64}(s.lower, prev_int.upper)
    return CI{SV,GT}(idx)
end
function MOI.add_constraint(opt::Optimizer, f::SV, s::LT)
    MOI.throw_if_not_valid(opt, f.variable)
    idx = f.variable.value
    prev_int = opt.form.base_form.feasible_region.bounds[idx]
    opt.form.base_form.feasible_region.bounds[idx] = MOI.Interval{Float64}(prev_int.lower, s.upper)
    return CI{SV,LT}(idx)
end
function MOI.add_constraint(opt::Optimizer, f::SV, s::INT)
    MOI.throw_if_not_valid(opt, f.variable)
    idx = f.variable.value
    opt.form.base_form.feasible_region.bounds[idx] = MOI.Interval{Float64}(s.lower, s.upper)
    return CI{SV,INT}(idx)
end

MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{<:_INT_SETS}) = true
function MOI.add_constraint(opt::Optimizer, f::SV, set::S) where {S <: _INT_SETS}
    vi = f.variable
    MOI.throw_if_not_valid(opt, vi)
    if opt.form.integrality[vi.value] !== nothing
        error("Already set variable integrality of $(opt.form.integrality[vi.value]) for $(vi); cannot overwrite to $set.")
    end
    opt.form.integrality[vi.value] = set
    return CI{SV,S}(vi.value)
end

function MOI.get(opt::Optimizer, ::MOI.NumberOfVariables)
    return num_variables(opt.form)
end

function MOI.get(opt::Optimizer, ::MOI.ListOfVariableIndices)
    return [VI(i) for i in 1:num_variables(opt.form)]
end

function MOI.get(
    opt::Optimizer,
    ::MOI.NumberOfConstraints{SV,S},
) where {S <: _V_SETS}
    cnt = 0
    for i in 1:num_variables(opt.form)
        p = opt.form.base_form.feasible_region
        if S == _get_scalar_set(p, i)
            cnt += 1
        end
    end
    return cnt
end

function MOI.get(
    opt::Optimizer,
    ::MOI.ListOfConstraintIndices{SV,S},
) where {S <: _V_SETS}
    indices = CI{SV,S}[]
    for i in 1:num_variables(opt.form)
        p = opt.form.base_form.feasible_region
        if S == _get_scalar_set(p, i)
            push!(indices, CI{SV,S}(i))
        end
    end
    return indices
end

MOI.supports(::Optimizer, ::MOI.ConstraintPrimal, ::CI{SV,<:_V_SETS}) = true
function MOI.get(
    opt::Optimizer,
    ::MOI.ConstraintPrimal,
    ci::CI{SV,S},
) where {S <: _V_SETS}
    vi = VI(ci.value)
    MOI.throw_if_not_valid(opt, vi)
    return MOI.get(opt, MOI.VariablePrimal(), vi)
end