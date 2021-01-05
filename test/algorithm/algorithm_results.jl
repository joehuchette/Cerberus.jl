@testset "Result" begin
    let state = _CurrentState(1, CONFIG)
        result = @inferred Cerberus.Result(state, CONFIG)
        @test result.primal_bound == Inf
        @test result.dual_bound == -Inf
        @test result.termination_status == Cerberus.EARLY_TERMINATION
        @test result.total_node_count == 0
        @test result.total_simplex_iters == 0
    end

    let state = _CurrentState(2, CONFIG, primal_bound = 12.4)
        result = @inferred Cerberus.Result(state, CONFIG)
        @test result.primal_bound == 12.4
        @test result.dual_bound == -Inf
        @test result.termination_status == Cerberus.EARLY_TERMINATION
        @test result.total_node_count == 0
        @test result.total_simplex_iters == 0
    end
end
