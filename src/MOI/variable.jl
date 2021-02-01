function MOI.add_variable(opt::Optimizer)
    add_variable(opt.form)
    return VI(num_variables(opt.form))
end

function MOI.add_variables(opt::Optimizer, N::Int)
    return [MOI.add_variable(opt) for i in 1:N]
end

function MOI.is_valid(opt::Optimizer, v::VI)
    return 1 <= v.value <= num_variables(opt.form)
end

function MOI.get(opt::Optimizer, ::MOI.VariablePrimal, vi::VI)
    MOI.throw_if_not_valid(opt, vi)
    return opt.result.best_solution[vi.value]
end

function MOI.supports_constraint(
    ::Optimizer,
    ::Type{SV},
    ::Type{<:_V_BOUND_SETS},
)
    return true
end

# TODO: This might "lie" to you: For example, if you set
# both a GT and LT constraint, this will report it as an
# IN constraint.
function _get_scalar_set(form::DMIPFormulation, cvi::CVI)
    l, u = get_bounds(form, cvi)
    if -Inf < l == u < Inf
        return ET
    elseif -Inf < l && u == Inf
        return GT
    elseif l == -Inf && u < Inf
        return LT
    elseif -Inf < l <= u < Inf
        return IN
    else
        @assert l == -Inf && u == Inf
        return nothing
    end
end

function MOI.is_valid(opt::Optimizer, c::CI{SV,S}) where {S<:_V_BOUND_SETS}
    MOI.is_valid(opt, VI(c.value)) || return false
    cvi = CVI(c.value)
    return S == _get_scalar_set(opt.form, cvi)
end

function MOI.get(
    opt::Optimizer,
    ::MOI.ConstraintFunction,
    c::CI{SV,<:_V_BOUND_SETS},
)
    MOI.throw_if_not_valid(opt, c)
    return SV(VI(c.value))
end

# TODO: Do we need to throw if bounds are already set?
function MOI.add_constraint(opt::Optimizer, f::SV, s::ET)
    MOI.throw_if_not_valid(opt, f.variable)
    cvi = convert(CVI, f.variable)
    set_bounds!(opt.form, cvi, IN(s.value, s.value))
    return CI{SV,ET}(index(cvi))
end
function MOI.add_constraint(opt::Optimizer, f::SV, s::GT)
    MOI.throw_if_not_valid(opt, f.variable)
    cvi = convert(CVI, f.variable)
    l, u = get_bounds(opt.form, cvi)
    set_bounds!(opt.form, cvi, IN(s.lower, u))
    return CI{SV,GT}(index(cvi))
end
function MOI.add_constraint(opt::Optimizer, f::SV, s::LT)
    MOI.throw_if_not_valid(opt, f.variable)
    cvi = convert(CVI, f.variable)
    l, u = get_bounds(opt.form, cvi)
    set_bounds!(opt.form, cvi, IN(l, s.upper))
    return CI{SV,LT}(index(cvi))
end
function MOI.add_constraint(opt::Optimizer, f::SV, s::IN)
    MOI.throw_if_not_valid(opt, f.variable)
    cvi = convert(CVI, f.variable)
    l, u = get_bounds(opt.form, cvi)
    set_bounds!(opt.form, cvi, IN(s.lower, s.upper))
    return CI{SV,IN}(index(cvi))
end

MOI.supports_constraint(::Optimizer, ::Type{SV}, ::Type{<:_V_INT_SETS}) = true
function MOI.add_constraint(
    opt::Optimizer,
    f::SV,
    set::S,
) where {S<:_V_INT_SETS}
    vi = f.variable
    MOI.throw_if_not_valid(opt, vi)
    cvi = convert(CVI, vi)
    if get_variable_kind(opt.form, cvi) !== nothing
        error(
            "Already set variable integrality of $(get_variable_kind(opt.form, cvi)) for $(vi); cannot overwrite to $set.",
        )
    end
    set_variable_kind!(opt.form, cvi, set)
    return CI{SV,S}(index(cvi))
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
) where {S<:_V_BOUND_SETS}
    cnt = 0
    for i in 1:num_variables(opt.form)
        if S == _get_scalar_set(opt.form, CVI(i))
            cnt += 1
        end
    end
    return cnt
end

function MOI.get(
    opt::Optimizer,
    ::MOI.ListOfConstraintIndices{SV,S},
) where {S<:_V_BOUND_SETS}
    indices = CI{SV,S}[]
    for i in 1:num_variables(opt.form)
        if S == _get_scalar_set(opt.form, CVI(i))
            push!(indices, CI{SV,S}(i))
        end
    end
    return indices
end

function MOI.supports(
    ::Optimizer,
    ::MOI.ConstraintPrimal,
    ::CI{SV,<:_V_BOUND_SETS},
)
    return true
end
function MOI.get(
    opt::Optimizer,
    ::MOI.ConstraintPrimal,
    ci::CI{SV,S},
) where {S<:_V_BOUND_SETS}
    vi = VI(ci.value)
    MOI.throw_if_not_valid(opt, vi)
    return MOI.get(opt, MOI.VariablePrimal(), vi)
end
