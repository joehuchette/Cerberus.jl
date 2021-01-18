@testset "Result" begin
    fm = _build_dmip_formulation()
    let state = _CurrentState(fm, CONFIG)
        result = @inferred Cerberus.Result(state, CONFIG)
        @test result.primal_bound == Inf
        @test result.dual_bound == -Inf
        @test result.termination_status == Cerberus.EARLY_TERMINATION
        @test result.total_node_count == 0
        @test result.total_simplex_iters == 0
    end

    let state = _CurrentState(fm, CONFIG, primal_bound = 12.4)
        result = @inferred Cerberus.Result(state, CONFIG)
        @test result.primal_bound == 12.4
        @test result.dual_bound == -Inf
        @test result.termination_status == Cerberus.EARLY_TERMINATION
        @test result.total_node_count == 0
        @test result.total_simplex_iters == 0
    end
end
