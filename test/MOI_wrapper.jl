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

# const MOIB = MOI.Bridges

# model = Cerberus.Optimizer()
# model.config.lp_solver_factory = (state, config) -> (begin
#     model = Gurobi.Optimizer(GRB_ENV)
#     MOI.set(model, MOI.Silent(), true)
#     MOI.set(model, MOI.RawParameter("DualReductions"), 0)
#     MOI.set(model, MOI.RawParameter("InfUnbdInfo"), 1)
#     model
# end)

# const OPTIMIZER = MOIU.CachingOptimizer(
#     MOIU.UniversalFallback(MOIU.Model{Float64}()),
#     MOIB.LazyBridgeOptimizer(model),
# )

# MOIB.add_bridge(OPTIMIZER, MOIB.VectorizeBridge)
# MOIB.add_bridge(OPTIMIZER, )

const CONFIG = MOIT.TestConfig(
    modify_lhs=false,
    duals=false,
    dual_objective_value=false,
    infeas_certificates=false,
)

@testset "basic_constraint_tests" begin
    MOIT.basic_constraint_tests(
        OPTIMIZER,
        CONFIG,
        delete=false,
        # TODO: Add support for getting F/S
        get_constraint_function=false,
        get_constraint_set=false,
        include=[
            (MOI.SingleVariable, MOI.LessThan{Float64}),
            (MOI.SingleVariable, MOI.GreaterThan{Float64}),
            (MOI.SingleVariable, MOI.EqualTo{Float64}),
            (MOI.SingleVariable, MOI.Interval{Float64}),
            (MOI.SingleVariable, MOI.ZeroOne),
            (MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}),
            (MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}),
            (MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}),
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

@testset "contlinear" begin
    MOIT.contlineartest(
        OPTIMIZER,
        CONFIG,
        [
            # Needs vector constraints
            "linear7",
            "linear15",

            # Needs SAF-in-Interval constraints
            "linear10",
            "linear10b",

            # Needs setting of VariablePrimalStart
            "partial_start",
        ],
    )
end

# TODO: Add bridges to support below sets
@testset "intlinear" begin
    MOIT.intlineartest(
        OPTIMIZER,
        CONFIG,
        [
            # Needs SOS1/SOS2
            "int2",

            # Needs SAF-in-Interval
            "int3",

            # Needs MOI.ACTIVATE_ON_ONE
            "indicator1",
            "indicator2",
            "indicator3",
            "indicator4",

            # Needs MOI.Semicontinuous
            "semiconttest",

            # Needs MOI.semiinteger
            "semiinttest",
        ],
    )
end
