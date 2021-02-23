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
        state = _CurrentState()
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
        state = _CurrentState()
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
        state = _CurrentState()
        # A bit hacky, but force infeasibility by branching both up and down.
        node = Cerberus.Node(
            [Cerberus.BoundUpdate(_CVI(1), _LT(0.0))],
            [Cerberus.BoundUpdate(_CVI(1), _GT(1.0))],
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
    let form = _build_dmip_formulation()
        state = Cerberus.CurrentState()
        let x_int = [1.0, 3.2, 0.0]
            state.current_solution = x_int
            @test Cerberus._num_int_infeasible(state, form, CONFIG) == 0
        end
        let x_int = [1.0 - 0.9CONFIG.int_tol, 3.2, 0.0 + 0.9CONFIG.int_tol]
            state.current_solution = x_int
            @test Cerberus._num_int_infeasible(state, form, CONFIG) == 0
        end
        let x_int = [1.0 - 2CONFIG.int_tol, 3.2, 0.0 + 1.1CONFIG.int_tol]
            state.current_solution = x_int
            @test Cerberus._num_int_infeasible(state, form, CONFIG) == 2
        end
    end

    let form = _build_gi_dmip_formulation()
        state = Cerberus.CurrentState()
        x_int = [0.6, 0.0, 2.0]
        state.current_solution = x_int
        @test Cerberus._num_int_infeasible(state, form, CONFIG) == 0
        x_int[2] = 0.9
        @test Cerberus._num_int_infeasible(state, form, CONFIG) == 1
        x_int[2] = 1.0
        x_int[3] = 3.0
        @test Cerberus._num_int_infeasible(state, form, CONFIG) == 0
        x_int[2] = 1.0
        x_int[3] = 2.9
        @test Cerberus._num_int_infeasible(state, form, CONFIG) == 1
    end
end

@testset "_store_basis_if_desired!" begin
    fm = _build_dmip_formulation()
    state = Cerberus.CurrentState()
    node = Cerberus.Node()
    Cerberus.process_node!(state, fm, node, CONFIG)
    fc = Cerberus.Node(
        Cerberus.BoundUpdate{_LT}[],
        [Cerberus.BoundUpdate(_CVI(1), _GT(1.0))],
        Cerberus.AffineConstraint{_LT}[],
        Cerberus.AffineConstraint{_GT}[],
        2,
    )
    oc = Cerberus.Node(
        [Cerberus.BoundUpdate(_CVI(1), _LT(0.0))],
        Cerberus.BoundUpdate{_GT}[],
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
            (oc, fc),
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
            (oc, fc),
            warm_start_only_config,
        )
        @test length(state.warm_starts) == 2
        @test haskey(state.warm_starts, fc)
        fc_basis = state.warm_starts[fc]
        _test_is_equal_to_dmip_basis(fc_basis)
        @test haskey(state.warm_starts, oc)
        oc_basis = state.warm_starts[oc]
        _test_is_equal_to_dmip_basis(oc_basis)
        # TODO: Test more than one child
    end
    empty!(state.warm_starts)
    let warm_start_off_dives_config = Cerberus.AlgorithmConfig(
            warm_start_strategy = Cerberus.WARM_START_WHEN_BACKTRACKING,
            model_reuse_strategy = Cerberus.REUSE_MODEL_ON_DIVES,
        )
        @inferred Cerberus._store_basis_if_desired!(
            state,
            (oc, fc),
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
    state = _CurrentState(primal_bound = starting_pb)
    @test Cerberus._is_root_node(Cerberus.pop_node!(state.tree))
    node = Cerberus.Node()

    @test isempty(state.warm_starts)

    # 1. Prune by infeasibility
    let nr = Cerberus.NodeResult()
        nr.cost = Inf
        nr.simplex_iters = simplex_iters_per
        nr.int_infeas = 0
        @inferred Cerberus.update_state!(state, fm, node, nr, CONFIG)
        @test isempty(state.tree)
        @test state.total_node_count == 1
        @test state.primal_bound == starting_pb
        @test state.dual_bound == -Inf
        @test length(state.best_solution) == 0
        @test all(isnan, values(state.best_solution))
        @test state.total_simplex_iters == simplex_iters_per
        @test isempty(state.warm_starts)
    end
    state.backtracking = false
    state.rebuild_model = true

    # 2. Prune by bound
    let nr = Cerberus.NodeResult()
        nr.cost = 13.5
        frac_soln = [0.2, 3.4, 0.6]
        nr.x = frac_soln
        state.current_solution = nr.x
        nr.simplex_iters = simplex_iters_per
        nr.depth = depth
        nr.int_infeas = Cerberus._num_int_infeasible(state, fm, CONFIG) == 2
        @inferred Cerberus.update_state!(state, fm, node, nr, CONFIG)
        @test isempty(state.tree)
        @test state.total_node_count == 2
        @test state.primal_bound == starting_pb
        @test state.dual_bound == -Inf
        @test length(state.best_solution) == 0
        @test all(isnan, values(state.best_solution))
        @test state.total_simplex_iters == 2 * simplex_iters_per
        @test isempty(state.warm_starts)
    end
    state.backtracking = false
    state.rebuild_model = true

    # 3. Prune by integrality
    new_pb = 11.1
    int_soln = [1.0, 3.4, 0.0]
    let nr = Cerberus.NodeResult()
        nr.cost = new_pb
        nr.x = copy(int_soln)
        state.current_solution = nr.x
        nr.simplex_iters = simplex_iters_per
        nr.depth = depth
        nr.int_infeas = Cerberus._num_int_infeasible(state, fm, CONFIG)
        @test nr.int_infeas == 0
        @inferred Cerberus.update_state!(state, fm, node, nr, CONFIG)
        @test isempty(state.tree)
        @test state.total_node_count == 3
        @test state.primal_bound == new_pb
        @test state.dual_bound == -Inf
        @test state.best_solution == int_soln
        @test state.total_simplex_iters == 3 * simplex_iters_per
        @test isempty(state.warm_starts)
    end
    state.backtracking = false
    state.rebuild_model = true

    # 4. Branch
    let nr = Cerberus.process_node!(state, fm, node, CONFIG)
        db = 10.1
        frac_soln_2 = [0.0, 2.9, 0.6]
        nr.cost = db
        nr.x = frac_soln_2
        state.current_solution = nr.x
        nr.simplex_iters = simplex_iters_per
        nr.depth = depth
        nr.int_infeas = Cerberus._num_int_infeasible(state, fm, CONFIG)
        @test nr.int_infeas == 1
        @inferred Cerberus.update_state!(state, fm, node, nr, CONFIG)
        @test Cerberus.num_open_nodes(state.tree) == 2
        @test state.total_node_count == 4
        @test state.primal_bound == new_pb
        @test state.dual_bound == -Inf
        @test state.best_solution == int_soln
        @test state.total_simplex_iters == 4 * simplex_iters_per
        @inferred Cerberus.update_dual_bound!(state)
        @test state.dual_bound == db
        let fc = Cerberus.pop_node!(state.tree)
            @test fc.lt_bounds == [Cerberus.BoundUpdate(_CVI(3), _LT(0.0))]
            @test isempty(fc.gt_bounds)
            @test fc.dual_bound == db
            @test length(state.warm_starts) == 1
            @test !haskey(state.warm_starts, fc)
        end
        let oc = Cerberus.pop_node!(state.tree)
            @test isempty(oc.lt_bounds)
            @test oc.gt_bounds == [Cerberus.BoundUpdate(_CVI(3), _GT(1.0))]
            @test oc.dual_bound == db
            @test haskey(state.warm_starts, oc)
            oc_basis = state.warm_starts[oc]
            _test_is_equal_to_dmip_basis(oc_basis)
        end
    end
end
