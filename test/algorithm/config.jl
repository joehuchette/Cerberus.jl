@testset "AlgorithmConfig" begin
    let config = Cerberus.AlgorithmConfig()
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
    end

    let sf = _silent_gurobi_factory, config = Cerberus.AlgorithmConfig(lp_solver_factory=sf)
        @test config.lp_solver_factory == sf
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start == Cerberus.DEFAULT_WARM_START
        @test config.hot_start == Cerberus.DEFAULT_HOT_START
    end

    let br = Cerberus.PseudocostBranching(), config = Cerberus.AlgorithmConfig(branching_rule=br)
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.branching_rule == br
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start == Cerberus.DEFAULT_WARM_START
        @test config.hot_start == Cerberus.DEFAULT_HOT_START
    end

    let nl = 10.0, config = Cerberus.AlgorithmConfig(node_limit=nl)
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.node_limit == nl
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start == Cerberus.DEFAULT_WARM_START
        @test config.hot_start == Cerberus.DEFAULT_HOT_START
    end

    let gt = 10, config = Cerberus.AlgorithmConfig(gap_tol=gt)
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == gt
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start == Cerberus.DEFAULT_WARM_START
        @test config.hot_start == Cerberus.DEFAULT_HOT_START
    end

    let it = 1e-6, config = Cerberus.AlgorithmConfig(int_tol=it)
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == it
        @test config.warm_start == Cerberus.DEFAULT_WARM_START
        @test config.hot_start == Cerberus.DEFAULT_HOT_START
    end

    let ws = false, config = Cerberus.AlgorithmConfig(warm_start=ws)
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start == ws
        @test config.hot_start == Cerberus.DEFAULT_HOT_START
    end

    let hs = true, config = Cerberus.AlgorithmConfig(hot_start=hs)
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start == Cerberus.DEFAULT_WARM_START
        @test config.hot_start == hs
    end

    nl_bad = -1
    nl_bad_2 = 1.2
    gt_bad = -1.0
    it_bad = -1.3
    @test_throws AssertionError Cerberus.AlgorithmConfig(node_limit=nl_bad)
    @test_throws AssertionError Cerberus.AlgorithmConfig(node_limit=nl_bad)
    @test_throws AssertionError Cerberus.AlgorithmConfig(gap_tol=gt_bad)
    @test_throws AssertionError Cerberus.AlgorithmConfig(int_tol=it_bad)
end
