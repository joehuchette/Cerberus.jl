using Cerberus
using Gurobi
using MathOptInterface
using Test

const MOI = MathOptInterface
const MOIT = MOI.Test
const MOIU = MOI.Utilities

const GRB_ENV = isdefined(Main, :GRB_ENV) ? Main.GRB_ENV : Gurobi.Env()

const OPTIMIZER = MOIU.CachingOptimizer(
    MOIU.UniversalFallback(MOIU.Model{Float64}()),
    begin
        model = Cerberus.Optimizer()
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
        model
    end,
)

const CONFIG = MOIT.TestConfig(
    modify_lhs = false,
    duals = false,
    dual_objective_value = false,
    infeas_certificates = false,
)

@testset "basic_constraint_tests" begin
    MOIT.basic_constraint_tests(
        OPTIMIZER,
        CONFIG,
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
        CONFIG,
        [
            # Should add support for:
            "time_limit_sec",
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

const BRIDGED_OPTIMIZER = MOIB.LazyBridgeOptimizer(OPTIMIZER)
MOIB.add_bridge(BRIDGED_OPTIMIZER, MOIB.Constraint.ScalarizeBridge{Float64})
MOIB.add_bridge(BRIDGED_OPTIMIZER, MOIB.Constraint.SemiToBinaryBridge{Float64})
MOIB.add_bridge(BRIDGED_OPTIMIZER, MOIB.Constraint.SplitIntervalBridge{Float64})
MOIB.add_bridge(BRIDGED_OPTIMIZER, MOIB.Variable.ZerosBridge{Float64})

@testset "contlinear" begin
    MOIT.contlineartest(BRIDGED_OPTIMIZER, CONFIG, [
        # Needs setting of VariablePrimalStart
        "partial_start",
    ])
end

# TODO: Add bridges to support below sets
@testset "intlinear" begin
    MOIT.intlineartest(
        BRIDGED_OPTIMIZER,
        CONFIG,
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
