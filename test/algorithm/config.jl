@testset "AlgorithmConfig" begin
    let config = Cerberus.AlgorithmConfig()
        @test config.lp_solver_factory == Cerberus.DEFAULT_LP_SOLVER_FACTORY
        @test config.silent == Cerberus.DEFAULT_SILENT
        @test config.branching_rule == Cerberus.DEFAULT_BRANCHING_RULE
        @test config.time_limit_sec == Cerberus.DEFAULT_TIME_LIMIT_SEC
        @test config.node_limit == Cerberus.DEFAULT_NODE_LIMIT
        @test config.gap_tol == Cerberus.DEFAULT_GAP_TOL
        @test config.int_tol == Cerberus.DEFAULT_INTEGRALITY_TOL
        @test config.warm_start_strategy == Cerberus.DEFAULT_WARM_START_STRATEGY
        @test config.model_reuse_strategy ==
              Cerberus.DEFAULT_MODEL_REUSE_STRATEGY
        @test config.formulation_tightening_strategy ==
              Cerberus.DEFAULT_FORMULATION_TIGHTENING_STRATEGY
    end

    let lp = identity,
        sl = true,
        br = Cerberus.PseudocostBranching(),
        tl = 12.3,
        nl = 10,
        gt = 10.0,
        it = 1e-6,
        ws = Cerberus.NO_WARM_STARTS,
        mr = Cerberus.NO_MODEL_REUSE,
        ts = Cerberus.STATIC_FORMULATION,

        config = Cerberus.AlgorithmConfig(
            lp_solver_factory = lp,
            silent = sl,
            branching_rule = br,
            time_limit_sec = tl,
            node_limit = nl,
            gap_tol = gt,
            int_tol = it,
            warm_start_strategy = ws,
            model_reuse_strategy = mr,
            formulation_tightening_strategy = ts,
        )

        @test config.lp_solver_factory == lp
        @test config.silent == sl
        @test config.branching_rule == br
        @test config.time_limit_sec == tl
        @test config.node_limit == nl
        @test config.gap_tol == gt
        @test config.int_tol == it
        @test config.warm_start_strategy == ws
        @test config.model_reuse_strategy == mr
        @test config.formulation_tightening_strategy == ts
    end
end
