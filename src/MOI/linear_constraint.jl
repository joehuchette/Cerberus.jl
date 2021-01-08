
MOI.supports_constraint(::Optimizer, ::Type{SAF}, ::Type{<:_C_SETS}) = true

function MOI.is_valid(opt::Optimizer, c::CI{SAF,T}) where {T<:_C_SETS}
    return 1 <= c.value <= num_constraints(opt.form.base_form.feasible_region, T)
end

function MOI.add_constraint(opt::Optimizer, f::SAF, s::T) where {T <: _C_SETS}
    if !iszero(f.constant)
        throw(MOI.ScalarFunctionConstantNotZero{Float64,SAF,T}(f.constant))
    end
    p = opt.form.base_form.feasible_region
    add_constraint(p, AffineConstraint(f, s))
    return CI{SAF,T}(num_constraints(p, T))
end

function MOI.get(
    opt::Optimizer,
    ::MOI.NumberOfConstraints{SAF,S},
) where {S<:_C_SETS}
    return num_constraints(opt.form.base_form.feasible_region, S)
end

function MOI.get(
    opt::Optimizer,
    ::MOI.ListOfConstraintIndices{SAF,S},
) where {S<:_C_SETS}
    p = opt.form.base_form.feasible_region
    return CI{SAF,S}[CI{SAF,S}(i) for i in 1:num_constraints(p, S)]
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
    idx = ci.value
    aff = get_constraint(opt.form.base_form.feasible_region, S, idx)
    return MOIU.eval_variables(aff.f) do vi
        return MOI.get(opt, MOI.VariablePrimal(), vi)
    end
end
