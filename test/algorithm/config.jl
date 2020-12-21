@testset "AlgorithmConfig" begin
    config1 = Cerberus.AlgorithmConfig()
    @test config1.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
    @test config1.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
    @test config1.node_limit == Cerberus.DEFAULT_NODE_LIMIT
    @test config1.gap_tol == Cerberus.DEFAULT_GAP_TOL
    @test config1.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL

    sf = _silent_gurobi_factory
    br = Cerberus.PseudocostBranching()
    nl = 10.0
    gt = 10
    it = 1e-6

    config2 = Cerberus.AlgorithmConfig(lp_solver_factory=sf)
    @test config2.lp_solver_factory == sf
    @test config2.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
    @test config2.node_limit == Cerberus.DEFAULT_NODE_LIMIT
    @test config2.gap_tol == Cerberus.DEFAULT_GAP_TOL
    @test config2.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL

    config3 = Cerberus.AlgorithmConfig(branching_rule=br)
    @test config3.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
    @test config3.branching_rule == br
    @test config3.node_limit == Cerberus.DEFAULT_NODE_LIMIT
    @test config3.gap_tol == Cerberus.DEFAULT_GAP_TOL
    @test config3.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL

    config4 = Cerberus.AlgorithmConfig(node_limit=nl)
    @test config4.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
    @test config4.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
    @test config4.node_limit == nl
    @test config4.gap_tol == Cerberus.DEFAULT_GAP_TOL
    @test config4.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL

    config5 = Cerberus.AlgorithmConfig(gap_tol=gt)
    @test config5.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
    @test config5.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
    @test config5.node_limit == Cerberus.DEFAULT_NODE_LIMIT
    @test config5.gap_tol == gt
    @test config5.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL

    config6 = Cerberus.AlgorithmConfig(int_tol=it)
    @test config6.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
    @test config6.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
    @test config6.node_limit == Cerberus.DEFAULT_NODE_LIMIT
    @test config6.gap_tol == Cerberus.DEFAULT_GAP_TOL
    @test config6.int_tol == it

    nl_bad = -1
    nl_bad_2 = 1.2
    gt_bad = -1.0
    it_bad = -1.3
    @test_throws AssertionError Cerberus.AlgorithmConfig(node_limit=nl_bad)
    @test_throws AssertionError Cerberus.AlgorithmConfig(node_limit=nl_bad)
    @test_throws AssertionError Cerberus.AlgorithmConfig(gap_tol=gt_bad)
    @test_throws AssertionError Cerberus.AlgorithmConfig(int_tol=it_bad)
end
