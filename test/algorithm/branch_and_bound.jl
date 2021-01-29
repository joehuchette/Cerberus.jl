@testset "optimize!" begin
    fm = _build_dmip_formulation()
    result = @inferred Cerberus.optimize!(fm, CONFIG)
    @test result.primal_bound ≈ 0.1 / 2.1
    @test result.dual_bound ≈ 0.1 / 2.1
    @test length(result.best_solution) == 3
    @test result.best_solution ≈ [1.0, 2 / 2.1, 0.0]
    @test result.termination_status == Cerberus.OPTIMAL
    @test result.total_node_count == 3
    @test result.total_simplex_iters == 0
end

@testset "process_node!" begin
    # A feasible model
    let
        fm = _build_dmip_formulation()
        state = _CurrentState(fm, CONFIG)
        node = Cerberus.Node()
        result = @inferred Cerberus.process_node!(state, fm, node, CONFIG)
        @test result.cost ≈ 0.5 - 2.5 / 2.1
        @test result.simplex_iters == 0
        @test length(result.x) == 3
        @test result.x ≈ [0.5, 2.5 / 2.1, 0.0]

        true_basis = @inferred Cerberus.get_basis(state)
        _test_is_equal_to_dmip_basis(true_basis)
    end

    # A feasible model with no incrementalism
    let
        fm = _build_dmip_formulation()
        no_inc_config = Cerberus.AlgorithmConfig(
            warm_start_strategy = Cerberus.NO_WARM_STARTS,
            model_reuse_strategy = Cerberus.NO_MODEL_REUSE,
        )
        state = _CurrentState(fm, no_inc_config)
        node = Cerberus.Node()
        result =
            @inferred Cerberus.process_node!(state, fm, node, no_inc_config)
        @test result.cost ≈ 0.5 - 2.5 / 2.1
        @test result.simplex_iters == 0
        @test length(result.x) == 3
        @test result.x ≈ [0.5, 2.5 / 2.1, 0.0]
    end

    # An infeasible model
    let
        fm = _build_dmip_formulation()
        state = _CurrentState(fm, CONFIG)
        # A bit hacky, but force infeasibility by branching both up and down.
        node = Cerberus.Node(
            Cerberus.BoundDiff(_VI(1) => 1),
            Cerberus.BoundDiff(_VI(1) => 0),
            Cerberus.AffineConstraint{_LT}[],
            Cerberus.AffineConstraint{_GT}[],
            2,
        )
        result = @inferred Cerberus.process_node!(state, fm, node, CONFIG)
        @test result.cost == Inf
        @test result.simplex_iters == 0
        @test isempty(result.x)
        @test all(isnan, values(result.x))
    end
end

@testset "_num_int_infeasible" begin
    config = Cerberus.AlgorithmConfig()
    let fm = _build_dmip_formulation()
        x_int = [1.0, 3.2, 0.0]
        @test Cerberus._num_int_infeasible(fm, x_int, CONFIG) == 0
        x_int_2 = [1.0 - 0.9CONFIG.int_tol, 3.2, 0.0 + 0.9CONFIG.int_tol]
        @test Cerberus._num_int_infeasible(fm, x_int_2, config) == 0
        x_int_3 = [1.0 - 2CONFIG.int_tol, 3.2, 0.0 + 1.1CONFIG.int_tol]
        @test Cerberus._num_int_infeasible(fm, x_int_3, CONFIG) == 2
    end

    let fm = _build_gi_dmip_formulation()
        x_int = [0.6, 0.0, 2.0]
        @test Cerberus._num_int_infeasible(fm, x_int, CONFIG) == 0
        x_int[2] = 0.9
        @test Cerberus._num_int_infeasible(fm, x_int, CONFIG) == 1
        x_int[2] = 1.0
        x_int[3] = 3.0
        @test Cerberus._num_int_infeasible(fm, x_int, CONFIG) == 0
        x_int[2] = 1.0
        x_int[3] = 2.9
        @test Cerberus._num_int_infeasible(fm, x_int, CONFIG) == 1
    end
end

@testset "_store_basis_if_desired!" begin
    fm = _build_dmip_formulation()
    state = Cerberus.CurrentState(fm, CONFIG)
    node = Cerberus.Node()
    Cerberus.process_node!(state, fm, node, CONFIG)
    fc = Cerberus.Node(
        Cerberus.BoundDiff(_VI(1) => 1),
        Cerberus.BoundDiff(),
        Cerberus.AffineConstraint{_LT}[],
        Cerberus.AffineConstraint{_GT}[],
        2,
    )
    oc = Cerberus.Node(
        Cerberus.BoundDiff(),
        Cerberus.BoundDiff(_VI(1) => 0),
        Cerberus.AffineConstraint{_LT}[],
        Cerberus.AffineConstraint{_GT}[],
        2,
    )
    cost = 12.3
    result = Cerberus.NodeResult(cost, [1.2, 2.3, 3.4], 1492, 12, 13)
    let no_incrementalism_config = Cerberus.AlgorithmConfig(
            warm_start_strategy = Cerberus.NO_WARM_STARTS,
            model_reuse_strategy = Cerberus.NO_MODEL_REUSE,
        )
        @inferred Cerberus._store_basis_if_desired!(
            state,
            fc,
            oc,
            no_incrementalism_config,
        )
        @test isempty(state.warm_starts)
    end
    let warm_start_only_config = Cerberus.AlgorithmConfig(
            warm_start_strategy = Cerberus.WARM_START_WHENEVER_POSSIBLE,
            model_reuse_strategy = Cerberus.NO_MODEL_REUSE,
        )
        @inferred Cerberus._store_basis_if_desired!(
            state,
            fc,
            oc,
            warm_start_only_config,
        )
        @test length(state.warm_starts) == 2
        @test haskey(state.warm_starts, fc)
        fc_basis = state.warm_starts[fc]
        _test_is_equal_to_dmip_basis(fc_basis)
        @test haskey(state.warm_starts, oc)
        oc_basis = state.warm_starts[oc]
        _test_is_equal_to_dmip_basis(oc_basis)
    end
    empty!(state.warm_starts)
    let warm_start_off_dives_config = Cerberus.AlgorithmConfig(
            warm_start_strategy = Cerberus.WARM_START_WHEN_BACKTRACKING,
            model_reuse_strategy = Cerberus.REUSE_MODEL_ON_DIVES,
        )
        @inferred Cerberus._store_basis_if_desired!(
            state,
            fc,
            oc,
            warm_start_off_dives_config,
        )
        @test length(state.warm_starts) == 1
        @test haskey(state.warm_starts, oc)
        oc_basis = state.warm_starts[oc]
        _test_is_equal_to_dmip_basis(oc_basis)
    end
end

@testset "update_state!" begin
    fm = _build_dmip_formulation()
    starting_pb = 12.3
    simplex_iters_per = 18
    depth = 7
    cs = _CurrentState(fm, CONFIG, primal_bound = starting_pb)
    @test _is_root_node(Cerberus.pop_node!(cs.tree))
    node = Cerberus.Node()

    @test isempty(cs.warm_starts)

    # 1. Prune by infeasibility
    let nr = Cerberus.NodeResult()
        nr.cost = Inf
        nr.simplex_iters = simplex_iters_per
        nr.int_infeas = 0
        @inferred Cerberus.update_state!(cs, fm, node, nr, CONFIG)
        @test isempty(cs.tree)
        @test cs.total_node_count == 1
        @test cs.primal_bound == starting_pb
        @test cs.dual_bound == -Inf
        @test length(cs.best_solution) == Cerberus.num_variables(fm)
        @test all(isnan, values(cs.best_solution))
        @test cs.total_simplex_iters == simplex_iters_per
        @test isempty(cs.warm_starts)
    end
    cs.backtracking = false
    cs.rebuild_model = true

    # 2. Prune by bound
    let nr = Cerberus.NodeResult()
        nr.cost = 13.5
        frac_soln = [0.2, 3.4, 0.6]
        nr.x = frac_soln
        nr.simplex_iters = simplex_iters_per
        nr.depth = depth
        nr.int_infeas = Cerberus._num_int_infeasible(fm, nr.x, CONFIG)
        @test nr.int_infeas == 2
        @inferred Cerberus.update_state!(cs, fm, node, nr, CONFIG)
        @test isempty(cs.tree)
        @test cs.total_node_count == 2
        @test cs.primal_bound == starting_pb
        @test cs.dual_bound == -Inf
        @test length(cs.best_solution) == Cerberus.num_variables(fm)
        @test all(isnan, values(cs.best_solution))
        @test cs.total_simplex_iters == 2 * simplex_iters_per
        @test isempty(cs.warm_starts)
    end
    cs.backtracking = false
    cs.rebuild_model = true

    # 3. Prune by integrality
    new_pb = 11.1
    int_soln = [1.0, 3.4, 0.0]
    let nr = Cerberus.NodeResult()
        nr.cost = new_pb
        nr.x = copy(int_soln)
        nr.simplex_iters = simplex_iters_per
        nr.depth = depth
        nr.int_infeas = Cerberus._num_int_infeasible(fm, nr.x, CONFIG)
        @test nr.int_infeas == 0
        @inferred Cerberus.update_state!(cs, fm, node, nr, CONFIG)
        @test isempty(cs.tree)
        @test cs.total_node_count == 3
        @test cs.primal_bound == new_pb
        @test cs.dual_bound == -Inf
        @test cs.best_solution == int_soln
        @test cs.total_simplex_iters == 3 * simplex_iters_per
        @test isempty(cs.warm_starts)
    end
    cs.backtracking = false
    cs.rebuild_model = true

    # 4. Branch
    let nr = Cerberus.process_node!(cs, fm, node, CONFIG)
        db = 10.1
        frac_soln_2 = [0.0, 2.9, 0.6]
        nr.cost = db
        nr.x = frac_soln_2
        nr.simplex_iters = simplex_iters_per
        nr.depth = depth
        nr.int_infeas = Cerberus._num_int_infeasible(fm, nr.x, CONFIG)
        @inferred Cerberus.update_state!(cs, fm, node, nr, CONFIG)
        @test Cerberus.num_open_nodes(cs.tree) == 2
        @test cs.total_node_count == 4
        @test cs.primal_bound == new_pb
        @test cs.dual_bound == -Inf
        @test cs.best_solution == int_soln
        @test cs.total_simplex_iters == 4 * simplex_iters_per
        @inferred Cerberus.update_dual_bound!(cs)
        @test cs.dual_bound == db
        fc = Cerberus.pop_node!(cs.tree)
        @test fc.lb_diff == Cerberus.BoundDiff(_VI(3) => 1)
        @test fc.ub_diff == Cerberus.BoundDiff()
        @test fc.dual_bound == db
        @test length(cs.warm_starts) == 1
        @test !haskey(cs.warm_starts, fc)
        oc = Cerberus.pop_node!(cs.tree)
        @test oc.lb_diff == Cerberus.BoundDiff()
        @test oc.ub_diff == Cerberus.BoundDiff(_VI(3) => 0)
        @test oc.dual_bound == db
        @test haskey(cs.warm_starts, oc)
        oc_basis = cs.warm_starts[oc]
        _test_is_equal_to_dmip_basis(oc_basis)
    end
end
