function MOI.get(opt::Optimizer, ::MOI.TerminationStatus)
    if opt.result === nothing
        return MOI.OPTIMIZE_NOT_CALLED
    end
    stat = opt.result.termination_status
    if stat == OPTIMAL
        return MOI.OPTIMAL
    elseif stat == INFEASIBLE
        return MOI.INFEASIBLE
    elseif stat == INF_OR_UNBOUNDED
        return MOI.INFEASIBLE_OR_UNBOUNDED
    elseif stat == EARLY_TERMINATION
        # TODO: Plug in a time limit, which will invalidate this.
        return MOI.NODE_LIMIT
    elseif stat == NOT_OPTIMIZED
        return MOI.OPTIMIZE_NOT_CALLED
    else
        @warn "Unhandled termination status $stat."
        return MOI.OTHER_ERROR
    end
end

function _has_feasible_solution(opt::Optimizer)
    if opt.result === nothing
        return false
    end
    x = opt.result.best_solution
    return all(!isnan, x)
end

function MOI.get(opt::Optimizer, ::MOI.PrimalStatus)
    if opt.result === nothing
        return MOI.NO_SOLUTION
    end
    if _has_feasible_solution(opt)
        stat = opt.result.termination_status
        @assert stat != INFEASIBLE && stat != INF_OR_UNBOUNDED
        return MOI.FEASIBLE_POINT
    else
        return MOI.NO_SOLUTION
    end
end

function MOI.get(opt::Optimizer, ::MOI.ObjectiveValue)
    return if _is_max_sense(opt)
        -opt.result.primal_bound
    else
        opt.result.primal_bound
    end
end

function MOI.get(opt::Optimizer, ::Union{MOI.ObjectiveBound})
    return _is_max_sense(opt) ? -opt.result.dual_bound : opt.result.dual_bound
end

function MOI.get(opt::Optimizer, ::MOI.SolveTime)
    if opt.result === nothing
        return NaN
    end
    return opt.result.total_elapsed_time_sec
end

function MOI.get(opt::Optimizer, ::MOI.SimplexIterations)
    return opt.result.total_simplex_iters
end

function MOI.get(opt::Optimizer, ::MOI.NodeCount)
    return opt.result.total_node_count
end

function MOI.get(opt::Optimizer, ::MOI.RelativeGap)
    return _optimality_gap(primal, dual)
end

function MOI.get(opt::Optimizer, ::MOI.ResultCount)
    return _has_feasible_solution(opt) ? 1 : 0
end
