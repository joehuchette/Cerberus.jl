using Cerberus
using Gurobi
using MathOptInterface
using Test

const MOI = MathOptInterface
const MOIT = MOI.Test
const MOIU = MOI.Utilities

function _build_optimizer(
    warm_start::Bool,
    model_reuse_strategy::Cerberus.ModelReuseStrategy,
)
    return MOIU.CachingOptimizer(
        MOIU.UniversalFallback(MOIU.Model{Float64}()),
        begin
            model = Cerberus.Optimizer(Cerberus.AlgorithmConfig())
            model.config.lp_solver_factory =
                (state, config) -> (
                    begin
                        model = Gurobi.Optimizer(GRB_ENV)
                        MOI.set(model, MOI.Silent(), true)
                        MOI.set(model, MOI.RawParameter("DualReductions"), 0)
                        MOI.set(model, MOI.RawParameter("InfUnbdInfo"), 1)
                        return model
                    end
                )
            model.config.silent = true
            model.config.warm_start = warm_start
            model.config.model_reuse_strategy = model_reuse_strategy
            model
        end,
    )
end

const OPTIMIZER = _build_optimizer(true, Cerberus.REUSE_ON_DIVES)

const MOI_CONFIG = MOIT.TestConfig(
    modify_lhs = false,
    duals = false,
    dual_objective_value = false,
    infeas_certificates = false,
)

@testset "basic_constraint_tests" begin
    MOIT.basic_constraint_tests(
        OPTIMIZER,
        MOI_CONFIG,
        delete = false,
        # TODO: Add support for getting F/S
        get_constraint_function = false,
        get_constraint_set = false,
        include = [
            (_SV, _LT),
            (_SV, _GT),
            (_SV, _ET),
            (_SV, _IN),
            (_SV, _ZO),
            (_SV, _GI),
            (_SAF, _LT),
            (_SAF, _GT),
            (_SAF, _ET),
        ],
    )
end

@testset "unittest" begin
    MOIT.unittest(
        OPTIMIZER,
        MOI_CONFIG,
        [
            # Should add support for:
            "solve_result_index",

            # Can test with support for MOI.UNBOUNDED status:
            "solve_unbounded_model",

            # Can test with support for vectorized constraints:
            "solve_duplicate_terms_vector_affine",

            # Can test with bridge to SAF-in-Interval:
            "solve_affine_interval",

            # Will likely not support:
            "number_threads",
            "delete_variables",
            "delete_nonnegative_variables",
            "delete_soc_variables",
            "raw_status_string",
            "solve_farkas_interval_lower",
            "solve_farkas_interval_upper",
            "update_dimension_nonnegative_variables",
            "solve_qp_edge_cases",
            "solve_qcp_edge_cases",
            "solve_affine_deletion_edge_cases",
        ],
    )
end

@testset "default_objective" begin
    MOIT.default_objective_test(OPTIMIZER)
end

@testset "default_status" begin
    # Like MOIT.default_status_test, but doesn't test dual status
    @test MOI.get(OPTIMIZER, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
    @test MOI.get(OPTIMIZER, MOI.PrimalStatus()) == MOI.NO_SOLUTION
end

@testset "valid" begin
    MOIT.validtest(OPTIMIZER)
end

const MOIB = MOI.Bridges

function _build_bridged_optimizer(
    warm_start::Bool,
    model_reuse_strategy::Cerberus.ModelReuseStrategy,
)
    opt = _build_optimizer(warm_start, model_reuse_strategy)
    bridged_opt = MOIB.LazyBridgeOptimizer(opt)
    MOIB.add_bridge(bridged_opt, MOIB.Constraint.ScalarizeBridge{Float64})
    MOIB.add_bridge(bridged_opt, MOIB.Constraint.SemiToBinaryBridge{Float64})
    MOIB.add_bridge(bridged_opt, MOIB.Constraint.SplitIntervalBridge{Float64})
    MOIB.add_bridge(bridged_opt, MOIB.Variable.ZerosBridge{Float64})
    return bridged_opt
end

@testset "contlinear" begin
    MOIT.contlineartest(
        _build_bridged_optimizer(true, Cerberus.REUSE_ON_DIVES),
        MOI_CONFIG,
        [
            # Needs setting of VariablePrimalStart
            "partial_start",
        ],
    )
end

# TODO: Add bridges to support below sets
@testset "intlinear" begin
    for ws in (true, false),
        mr in
        (Cerberus.NO_REUSE, Cerberus.REUSE_ON_DIVES, Cerberus.USE_SINGLE_MODEL)

        MOIT.intlineartest(
            _build_bridged_optimizer(ws, mr),
            MOI_CONFIG,
            [
                # Needs SOS1/SOS2
                "int2",

                # Needs MOI.ACTIVATE_ON_ONE
                "indicator1",
                "indicator2",
                "indicator3",
                "indicator4",
            ],
        )
    end
end
