@testset "AlgorithmConfig" begin
    config1 = Cerberus.AlgorithmConfig()
    @test config1.node_limit == Cerberus.DEFAULT_NODE_LIMIT
    @test config1.gap_tol == Cerberus.DEFAULT_GAP_TOL

    nl = 10.0
    gt = 10
    config2 = Cerberus.AlgorithmConfig(nl, gt)
    @test config2.node_limit == nl
    @test config2.gap_tol == gt

    nl_bad = -1
    nl_bad_2 = 1.2
    gt_bad = -1.0
    @test_throws AssertionError Cerberus.AlgorithmConfig(nl_bad, gt)
    @test_throws AssertionError Cerberus.AlgorithmConfig(nl_bad_2, gt)
    @test_throws AssertionError Cerberus.AlgorithmConfig(nl, gt_bad)
end
