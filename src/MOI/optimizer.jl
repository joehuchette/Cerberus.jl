mutable struct Optimizer <: MOI.AbstractOptimizer
    form::DMIPFormulation
    obj_sense::MOI.OptimizationSense
    primal_bound::Float64
    config::AlgorithmConfig
    result::Union{Nothing,Result}

    function Optimizer(; config::AlgorithmConfig = AlgorithmConfig())
        return new(
            DMIPFormulation(),
            MOI.FEASIBILITY_SENSE,
            NaN,
            config,
            nothing,
        )
    end
end

_is_max_sense(opt::Optimizer) = opt.obj_sense == MOI.MAX_SENSE

function _get_primal_bound(opt::Optimizer)
    return isnan(opt.primal_bound) ? Inf : opt.primal_bound
end

MOI.get(::Optimizer, ::MOI.SolverName) = "Cerberus"
MOI.get(opt::Optimizer, ::MOI.RawSolver) = opt.form

# TODO: Figure out what to say here
function MOI.is_empty(opt::Optimizer)
    return isempty(opt.form) &&
           opt.obj_sense == MOI.FEASIBILITY_SENSE &&
           isnan(opt.primal_bound) &&
           opt.result === nothing
end

# TODO: Add empty! method called here...
function MOI.empty!(opt::Optimizer)
    opt.form = DMIPFormulation()
    opt.obj_sense = MOI.FEASIBILITY_SENSE
    opt.primal_bound = NaN
    opt.result = nothing
    return nothing
end

function MOI.optimize!(opt::Optimizer)
    if _is_max_sense(opt)
        opt.form.base_form.obj *= -1.0
    end
    opt.result = optimize!(opt.form, opt.config, _get_primal_bound(opt))
    if _is_max_sense(opt)
        opt.form.base_form.obj *= -1.0
    end
    return nothing
end

# TODO: Make this so by adding silent field, plugging it in.
MOI.supports(::Optimizer, ::MOI.Silent) = true
function MOI.set(opt::Optimizer, ::MOI.Silent, value::Bool)
    opt.config.silent = value
    return nothing
end
MOI.get(opt::Optimizer, ::MOI.Silent) = opt.config.silent

MOIU.supports_default_copy_to(opt::Optimizer, copy_names::Bool) = !copy_names
function MOI.copy_to(dest::Optimizer, src::MOI.ModelLike; kws...)
    return MOI.Utilities.automatic_copy_to(dest, src; kws...)
end
