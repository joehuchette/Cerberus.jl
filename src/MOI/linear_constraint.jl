const _C_SETS = Union{ET,GT,LT}

MOI.supports_constraint(::Optimizer, ::Type{SAF}, ::Type{<:_C_SETS}) = true

function MOI.is_valid(opt::Optimizer, c::CI{SAF,T}) where {T<:_C_SETS}
    1 <= c.value <= num_constraints(opt.form.base_form.feasible_region) ||
        return false
    constr = opt.form.base_form.feasible_region.aff_constrs[c.value]
    return T == typeof(constr.s)
end

function MOI.add_constraint(opt::Optimizer, f::SAF, s::_C_SETS)
    if !iszero(f.constant)
        throw(MOI.ScalarFunctionConstantNotZero{Float64,typeof(f),typeof(s)}(f.constant))
    end
    aff_constrs = opt.form.base_form.feasible_region.aff_constrs
    push!(aff_constrs, AffineConstraint(f, s))
    return CI{SAF,typeof(s)}(length(aff_constrs))
end

function MOI.get(
    opt::Optimizer,
    ::MOI.NumberOfConstraints{SAF,S},
) where {S<:_C_SETS}
    cnt = 0
    for aff in opt.form.base_form.feasible_region.aff_constrs
        if S == typeof(aff.s)
            cnt += 1
        end
    end
    return cnt
end

function MOI.get(
    opt::Optimizer,
    ::MOI.ListOfConstraintIndices{SAF,S},
) where {S<:_C_SETS}
    indices = CI{SAF,S}[]
    for (i, aff) in enumerate(opt.form.base_form.feasible_region.aff_constrs)
        if S == typeof(aff.s)
            push!(indices, CI{SAF,S}(i))
        end
    end
    return indices
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
    aff = opt.form.base_form.feasible_region.aff_constrs[idx]
    return MOIU.eval_variables(aff.f) do vi
        return MOI.get(opt, MOI.VariablePrimal(), vi)
    end
end
