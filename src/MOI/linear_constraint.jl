
MOI.supports_constraint(::Optimizer, ::Type{SAF}, ::Type{<:_C_SETS}) = true

function MOI.is_valid(opt::Optimizer, c::CI{SAF,T}) where {T<:_C_SETS}
    return 1 <= c.value <= num_constraints(opt.form, T)
end

function MOI.add_constraint(opt::Optimizer, f::SAF, s::T) where {T<:_C_SETS}
    if !iszero(f.constant)
        throw(MOI.ScalarFunctionConstantNotZero{Float64,SAF,T}(f.constant))
    end
    add_constraint(opt.form, AffineConstraint(f, s))
    return CI{SAF,T}(num_constraints(opt.form, T))
end

function MOI.get(
    opt::Optimizer,
    ::MOI.NumberOfConstraints{SAF,S},
) where {S<:_C_SETS}
    return num_constraints(opt.form, S)
end

function MOI.get(
    opt::Optimizer,
    ::MOI.ListOfConstraintIndices{SAF,S},
) where {S<:_C_SETS}
    return CI{SAF,S}[CI{SAF,S}(i) for i in 1:num_constraints(opt.form, S)]
end

function MOI.get(opt::Optimizer, ::MOI.ListOfConstraints)
    return error("TODO: Implement!")
end

MOI.supports(::Optimizer, ::MOI.ConstraintPrimal, ::CI{SAF,<:_C_SETS}) = true
function MOI.get(
    opt::Optimizer,
    ::MOI.ConstraintPrimal,
    ci::CI{SAF,S},
) where {S<:_C_SETS}
    MOI.throw_if_not_valid(opt, ci)
    if opt.result === nothing
        error("Model does not have a solution available.")
    end
    idx = ci.value
    ac = get_constraint(opt.form, S, idx)
    val = 0.0
    for (coeff, cvi) in zip(ac.f.coeffs, ac.f.indices)
        val += coeff * opt.result.best_solution[index(cvi)]
    end
    return val
end
