@testset "Result" begin
    fm = _build_dmip_formulation()
    let state = _CurrentState(fm)
        result = @inferred Cerberus.Result(state, CONFIG)
        @test result.primal_bound == Inf
        @test result.dual_bound == -Inf
        @test result.termination_status == Cerberus.EARLY_TERMINATION
        @test result.total_node_count == 0
        @test result.total_simplex_iters == 0
        @test result.total_model_builds == 0
        @test result.total_warm_starts == 0
    end

    let state = _CurrentState(fm, primal_bound = 12.4)
        result = @inferred Cerberus.Result(state, CONFIG)
        @test result.primal_bound == 12.4
        @test result.dual_bound == -Inf
        @test result.termination_status == Cerberus.EARLY_TERMINATION
        @test result.total_node_count == 0
        @test result.total_simplex_iters == 0
        @test result.total_model_builds == 0
        @test result.total_warm_starts == 0
    end
end

@testset "End-to-end" begin
    for (
        warm_start_strategy,
        model_reuse_strategy,
        model_builds,
        warm_starts,
    ) in [
        (Cerberus.NO_WARM_STARTS, Cerberus.NO_MODEL_REUSE, 3, 0),
        (Cerberus.NO_WARM_STARTS, Cerberus.REUSE_MODEL_ON_DIVES, 2, 0),
        (Cerberus.NO_WARM_STARTS, Cerberus.USE_SINGLE_MODEL, 1, 0),
        (Cerberus.WARM_START_WHEN_BACKTRACKING, Cerberus.NO_MODEL_REUSE, 3, 1),
        (
            Cerberus.WARM_START_WHEN_BACKTRACKING,
            Cerberus.REUSE_MODEL_ON_DIVES,
            2,
            1,
        ),
        (
            Cerberus.WARM_START_WHEN_BACKTRACKING,
            Cerberus.USE_SINGLE_MODEL,
            1,
            1,
        ),
        (Cerberus.WARM_START_WHENEVER_POSSIBLE, Cerberus.NO_MODEL_REUSE, 3, 2),
        (
            Cerberus.WARM_START_WHENEVER_POSSIBLE,
            Cerberus.REUSE_MODEL_ON_DIVES,
            2,
            2,
        ),
        (
            Cerberus.WARM_START_WHENEVER_POSSIBLE,
            Cerberus.USE_SINGLE_MODEL,
            1,
            2,
        ),
    ]
        config = Cerberus.AlgorithmConfig(
            warm_start_strategy = warm_start_strategy,
            model_reuse_strategy = model_reuse_strategy,
            silent = true,
        )
        fm = _build_dmip_formulation()
        result = Cerberus.optimize!(fm, config)
        @test result.primal_bound ≈ 1 / 21
        @test result.dual_bound ≈ 1 / 21
        @test result.best_solution ≈ [1.0, 20 / 21, 0.0]
        @test result.termination_status == Cerberus.OPTIMAL
        @test result.total_node_count == 3
        @test result.total_simplex_iters == 0
        @test result.total_elapsed_time_sec > 0
        @test result.total_model_builds == model_builds
        @test result.total_warm_starts == warm_starts
    end
end
