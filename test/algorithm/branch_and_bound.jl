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
        state = _CurrentState(Cerberus.num_variables(fm), CONFIG)
        node = Cerberus.Node()
        @inferred Cerberus.process_node!(state, fm, node, CONFIG)
        result = state.node_result
        @test result.cost ≈ 0.5 - 2.5 / 2.1
        @test result.simplex_iters == 0
        @test length(result.x) == 3
        @test result.x ≈ [0.5, 2.5 / 2.1, 0.0]
        @test Cerberus.get_basis(result) == Cerberus.Basis(
            _CI{_SV,_IN}(1) => MOI.NONBASIC_AT_LOWER,
            _CI{_SV,_IN}(2) => MOI.BASIC,
            _CI{_SV,_IN}(3) => MOI.NONBASIC_AT_LOWER,
            _CI{_SAF,_ET}(2) => MOI.NONBASIC,
            _CI{_SAF,_LT}(3) => MOI.BASIC,
        )
        @test Cerberus.get_model(result) isa Gurobi.Optimizer
    end

    # A feasible model with no incrementalism
    let
        fm = _build_dmip_formulation()
        no_inc_config = Cerberus.AlgorithmConfig(
            incrementalism = Cerberus.NO_INCREMENTALISM,
        )
        state = _CurrentState(Cerberus.num_variables(fm), no_inc_config)
        node = Cerberus.Node()
        @inferred Cerberus.process_node!(state, fm, node, no_inc_config)
        result = state.node_result
        @test result.cost ≈ 0.5 - 2.5 / 2.1
        @test result.simplex_iters == 0
        @test length(result.x) == 3
        @test result.x ≈ [0.5, 2.5 / 2.1, 0.0]
        @test_throws ErrorException Cerberus.get_basis(result)
        @test_throws ErrorException Cerberus.get_model(result)
    end

    # An infeasible model
    let
        fm = _build_dmip_formulation()
        state = _CurrentState(Cerberus.num_variables(fm), CONFIG)
        # A bit hacky, but force infeasibility by branching both up and down.
        node = Cerberus.Node([
            Cerberus.BranchingDecision(_VI(1), 0, Cerberus.DOWN_BRANCH),
            Cerberus.BranchingDecision(_VI(1), 1, Cerberus.UP_BRANCH),
        ])
        @inferred Cerberus.process_node!(state, fm, node, CONFIG)
        result = state.node_result
        @test result.cost == Inf
        @test result.simplex_iters == 0
        @test length(result.x) == Cerberus.num_variables(fm)
        @test all(isnan, values(result.x))
        @test isempty(Cerberus.get_basis(result))
        @test Cerberus.get_model(result) === nothing
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

@testset "_attach_parent_info!" begin
    fc = Cerberus.Node([
        Cerberus.BranchingDecision(_VI(1), 1, Cerberus.UP_BRANCH),
    ])
    oc = Cerberus.Node([
        Cerberus.BranchingDecision(_VI(1), 0, Cerberus.DOWN_BRANCH),
    ])
    basis = Cerberus.Basis(_VI(1) => MOI.BASIC)
    model = Gurobi.Optimizer()
    cost = 12.3
    result = Cerberus.NodeResult(
        cost,
        [1.2, 2.3, 3.4],
        1492,
        12,
        13,
        Cerberus.IncrementalData(Cerberus.HOT_START),
    )
    result.incremental_data._basis = basis
    Cerberus.set_model!(result, model)
    let no_inc_config = Cerberus.AlgorithmConfig(
            incrementalism = Cerberus.NO_INCREMENTALISM,
        )
        @inferred Cerberus._attach_parent_info!(fc, oc, result, no_inc_config)
        @test fc.parent_info.dual_bound == cost
        @test oc.parent_info.dual_bound == cost
        @test fc.parent_info.basis === nothing
        @test oc.parent_info.basis === nothing
        @test fc.parent_info.hot_start_model === nothing
        @test oc.parent_info.hot_start_model === nothing
    end
    let ws_config =
            Cerberus.AlgorithmConfig(incrementalism = Cerberus.WARM_START)
        @inferred Cerberus._attach_parent_info!(fc, oc, result, ws_config)
        @test fc.parent_info.dual_bound == cost
        @test oc.parent_info.dual_bound == cost
        @test fc.parent_info.basis === basis
        @test oc.parent_info.basis !== basis
        @test oc.parent_info.basis isa Cerberus.Basis
        @test length(oc.parent_info.basis) == 1
        @test haskey(oc.parent_info.basis, _VI(1))
        @test oc.parent_info.basis[_VI(1)] == MOI.BASIC
        @test fc.parent_info.hot_start_model === nothing
        @test oc.parent_info.hot_start_model === nothing
    end
    let hs_config =
            Cerberus.AlgorithmConfig(incrementalism = Cerberus.HOT_START)
        @inferred Cerberus._attach_parent_info!(fc, oc, result, hs_config)
        @test fc.parent_info.dual_bound == cost
        @test oc.parent_info.dual_bound == cost
        @test fc.parent_info.basis === nothing
        @test oc.parent_info.basis === basis
        @test fc.parent_info.hot_start_model === model
        @test oc.parent_info.hot_start_model === nothing
    end
end

@testset "update_state!" begin
    fm = _build_dmip_formulation()
    starting_pb = 12.3
    simplex_iters_per = 18
    depth = 7
    cs = _CurrentState(
        Cerberus.num_variables(fm),
        CONFIG,
        primal_bound = starting_pb,
    )
    @test _is_root_node(Cerberus.pop_node!(cs.tree))
    node = Cerberus.Node()

    # 1. Prune by infeasibility
    nr1 = Cerberus.NodeResult(Cerberus.num_variables(fm), CONFIG)
    cs.node_result.cost = Inf
    cs.node_result.simplex_iters = simplex_iters_per
    cs.node_result.depth = depth
    cs.node_result.int_infeas = 0
    @inferred Cerberus.update_state!(cs, fm, node, CONFIG)
    @test isempty(cs.tree)
    @test cs.total_node_count == 1
    @test cs.primal_bound == starting_pb
    @test cs.dual_bound == -Inf
    @test length(cs.best_solution) == Cerberus.num_variables(fm)
    @test all(isnan, values(cs.best_solution))
    @test cs.total_simplex_iters == simplex_iters_per

    # 2. Prune by bound
    frac_soln = [0.2, 3.4, 0.6]
    Cerberus.reset!(cs.node_result)
    cs.node_result.cost = 13.5
    cs.node_result.x = frac_soln
    cs.node_result.simplex_iters = simplex_iters_per
    cs.node_result.depth = depth
    cs.node_result.int_infeas =
        Cerberus._num_int_infeasible(fm, cs.node_result.x, CONFIG)
    @test cs.node_result.int_infeas == 2
    @inferred Cerberus.update_state!(cs, fm, node, CONFIG)
    @test isempty(cs.tree)
    @test cs.total_node_count == 2
    @test cs.primal_bound == starting_pb
    @test cs.dual_bound == -Inf
    @test length(cs.best_solution) == Cerberus.num_variables(fm)
    @test all(isnan, values(cs.best_solution))
    @test cs.total_simplex_iters == 2 * simplex_iters_per

    # 3. Prune by integrality
    int_soln = [1.0, 3.4, 0.0]
    new_pb = 11.1
    Cerberus.reset!(cs.node_result)
    cs.node_result.cost = new_pb
    cs.node_result.x = copy(int_soln)
    cs.node_result.simplex_iters = simplex_iters_per
    cs.node_result.depth = depth
    cs.node_result.int_infeas =
        Cerberus._num_int_infeasible(fm, cs.node_result.x, CONFIG)
    @test cs.node_result.int_infeas == 0
    @inferred Cerberus.update_state!(cs, fm, node, CONFIG)
    @test isempty(cs.tree)
    @test cs.total_node_count == 3
    @test cs.primal_bound == new_pb
    @test cs.dual_bound == -Inf
    @test cs.best_solution == int_soln
    @test cs.total_simplex_iters == 3 * simplex_iters_per

    # 4. Branch
    frac_soln_2 = [0.0, 2.9, 0.6]
    db = 10.1
    basis = Cerberus.Basis(_CI{_SV,_IN}(1) => MOI.BASIC)
    model = Gurobi.Optimizer()
    Cerberus.reset!(cs.node_result)
    cs.node_result.cost = 10.1
    cs.node_result.x = frac_soln_2
    cs.node_result.simplex_iters = simplex_iters_per
    cs.node_result.depth = depth
    cs.node_result.int_infeas =
        Cerberus._num_int_infeasible(fm, cs.node_result.x, CONFIG)
    @test cs.node_result.int_infeas == 1
    cs.node_result.incremental_data._basis = basis
    Cerberus.set_model!(cs.node_result, model)
    @inferred Cerberus.update_state!(cs, fm, node, CONFIG)
    @test Cerberus.num_open_nodes(cs.tree) == 2
    @test cs.total_node_count == 4
    @test cs.primal_bound == new_pb
    @test cs.dual_bound == -Inf
    @test cs.best_solution == int_soln
    @test cs.total_simplex_iters == 4 * simplex_iters_per
    @inferred Cerberus.update_dual_bound!(cs)
    @test cs.dual_bound == db
    fc = Cerberus.pop_node!(cs.tree)
    @test fc.branchings ==
          [Cerberus.BranchingDecision(_VI(3), 1, Cerberus.UP_BRANCH)]
    @test fc.parent_info.dual_bound == db
    @test fc.parent_info.basis === nothing
    @test fc.parent_info.hot_start_model === model
    oc = Cerberus.pop_node!(cs.tree)
    @test oc.branchings ==
          [Cerberus.BranchingDecision(_VI(3), 0, Cerberus.DOWN_BRANCH)]
    @test oc.parent_info.dual_bound == db
    @test oc.parent_info.basis == basis
    @test oc.parent_info.hot_start_model === nothing
end
