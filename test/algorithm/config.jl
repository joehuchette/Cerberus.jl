@testset "AlgorithmConfig" begin
    let config = Cerberus.AlgorithmConfig()
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.silent == Cerberus.DEFAULT_SILENT
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.time_limit_sec == Cerberus.DEFAULT_TIME_LIMIT_SEC
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.incrementalism == Cerberus.DEFAULT_INCREMENTALISM
        @test config.log_output == Cerberus.DEFAULT_LOG_OUTPUT
    end

    let lp = identity,
        sl = true,
        br = Cerberus.PseudocostBranching(),
        tl = 12.3,
        nl = 10.0,
        gt = 10,
        it = 1e-6,
        in = Cerberus.NO_INCREMENTALISM,
        lo = false

        config = Cerberus.AlgorithmConfig(lp_solver_factory = lp, silent = sl, branching_rule = br, time_limit_sec = tl, node_limit = nl, gap_tol = gt, int_tol = it, incrementalism = in, log_output = lo)
        @test config.lp_solver_factory == lp
        @test config.silent == sl
        @test config.branching_rule == br
        @test config.time_limit_sec == tl
        @test config.node_limit == nl
        @test config.gap_tol == gt
        @test config.int_tol == it
        @test config.incrementalism == in
        @test config.log_output == lo
    end
end
