@testset "AlgorithmConfig" begin
    let config = Cerberus.AlgorithmConfig()
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.silent == Cerberus.DEFAULT_SILENT
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.time_limit_sec == Cerberus.DEFAULT_TIME_LIMIT_SEC
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start == Cerberus.DEFAULT_WARM_START
        @test config.hot_start == Cerberus.DEFAULT_HOT_START
        @test config.log_output == Cerberus.DEFAULT_LOG_OUTPUT
    end

    let sl = true, config = Cerberus.AlgorithmConfig(silent = sl)
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.silent == sl
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.time_limit_sec == Cerberus.DEFAULT_TIME_LIMIT_SEC
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start == Cerberus.DEFAULT_WARM_START
        @test config.hot_start == Cerberus.DEFAULT_HOT_START
        @test config.log_output == Cerberus.DEFAULT_LOG_OUTPUT
    end

    let br = Cerberus.PseudocostBranching(),
        config = Cerberus.AlgorithmConfig(branching_rule = br)

        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.silent == Cerberus.DEFAULT_SILENT
        @test config.branching_rule == br
        @test config.time_limit_sec == Cerberus.DEFAULT_TIME_LIMIT_SEC
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start == Cerberus.DEFAULT_WARM_START
        @test config.hot_start == Cerberus.DEFAULT_HOT_START
        @test config.log_output == Cerberus.DEFAULT_LOG_OUTPUT
    end

    let tl = 12.3, config = Cerberus.AlgorithmConfig(time_limit_sec = tl)
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.silent == Cerberus.DEFAULT_SILENT
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.time_limit_sec == tl
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start == Cerberus.DEFAULT_WARM_START
        @test config.hot_start == Cerberus.DEFAULT_HOT_START
        @test config.log_output == Cerberus.DEFAULT_LOG_OUTPUT
    end

    let nl = 10.0, config = Cerberus.AlgorithmConfig(node_limit = nl)
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.silent == Cerberus.DEFAULT_SILENT
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.time_limit_sec == Cerberus.DEFAULT_TIME_LIMIT_SEC
        @test config.node_limit == nl
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start == Cerberus.DEFAULT_WARM_START
        @test config.hot_start == Cerberus.DEFAULT_HOT_START
        @test config.log_output == Cerberus.DEFAULT_LOG_OUTPUT
    end

    let gt = 10, config = Cerberus.AlgorithmConfig(gap_tol = gt)
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.silent == Cerberus.DEFAULT_SILENT
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.time_limit_sec == Cerberus.DEFAULT_TIME_LIMIT_SEC
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == gt
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start == Cerberus.DEFAULT_WARM_START
        @test config.hot_start == Cerberus.DEFAULT_HOT_START
        @test config.log_output == Cerberus.DEFAULT_LOG_OUTPUT
    end

    let it = 1e-6, config = Cerberus.AlgorithmConfig(int_tol = it)
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.silent == Cerberus.DEFAULT_SILENT
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.time_limit_sec == Cerberus.DEFAULT_TIME_LIMIT_SEC
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == it
        @test config.warm_start == Cerberus.DEFAULT_WARM_START
        @test config.hot_start == Cerberus.DEFAULT_HOT_START
        @test config.log_output == Cerberus.DEFAULT_LOG_OUTPUT
    end

    let ws = false, config = Cerberus.AlgorithmConfig(warm_start = ws)
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.silent == Cerberus.DEFAULT_SILENT
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.time_limit_sec == Cerberus.DEFAULT_TIME_LIMIT_SEC
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start == ws
        @test config.hot_start == Cerberus.DEFAULT_HOT_START
        @test config.log_output == Cerberus.DEFAULT_LOG_OUTPUT
    end

    let hs = true, config = Cerberus.AlgorithmConfig(hot_start = hs)
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.silent == Cerberus.DEFAULT_SILENT
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.time_limit_sec == Cerberus.DEFAULT_TIME_LIMIT_SEC
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start == Cerberus.DEFAULT_WARM_START
        @test config.hot_start == hs
        @test config.log_output == Cerberus.DEFAULT_LOG_OUTPUT
    end

    let lo = false, config = Cerberus.AlgorithmConfig(log_output = lo)
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.silent == Cerberus.DEFAULT_SILENT
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.time_limit_sec == Cerberus.DEFAULT_TIME_LIMIT_SEC
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start == Cerberus.DEFAULT_WARM_START
        @test config.hot_start == Cerberus.DEFAULT_HOT_START
        @test config.log_output == lo
    end
end
