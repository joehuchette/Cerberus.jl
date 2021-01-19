@testset "Result" begin
    fm = _build_dmip_formulation()
    let state = _CurrentState(fm, CONFIG)
        result = @inferred Cerberus.Result(state, CONFIG)
        @test result.primal_bound == Inf
        @test result.dual_bound == -Inf
        @test result.termination_status == Cerberus.EARLY_TERMINATION
        @test result.total_node_count == 0
        @test result.total_simplex_iters == 0
        @test result.total_model_builds == 0
        @test result.total_warm_starts == 0
    end

    let state = _CurrentState(fm, CONFIG, primal_bound = 12.4)
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
    for (incrementalism, model_builds, warm_starts) in [
        (Cerberus.NO_INCREMENTALISM, 3, 0),
        (Cerberus.WARM_START, 3, 2),
        (Cerberus.HOT_START, 2, 1),
    ]
        config = Cerberus.AlgorithmConfig(
            incrementalism = incrementalism,
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
