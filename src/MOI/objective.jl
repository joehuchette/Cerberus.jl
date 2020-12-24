MOI.supports(::Optimizer, ::MOI.ObjectiveSense) = true
function MOI.set(
    opt::Optimizer,
    ::MOI.ObjectiveSense,
    sense::MOI.OptimizationSense,
)
    opt.obj_sense = sense
    return nothing
end
MOI.get(opt::Optimizer, ::MOI.ObjectiveSense) = opt.obj_sense

const _O_FUNCS = Union{SV,SAF}

MOI.supports(::Optimizer, ::MOI.ObjectiveFunction{F}) where {F<:_O_FUNCS} = true
function MOI.set(
    opt::Optimizer,
    ::MOI.ObjectiveFunction{F},
    obj::F,
) where {F<:_O_FUNCS}
    opt.form.base_form.obj = convert(SAF, obj)
    return nothing
end
function MOI.get(opt::Optimizer, ::MOI.ObjectiveFunction{F}) where {F<:_O_FUNCS}
    return convert(F, opt.form.base_form.obj)
end
