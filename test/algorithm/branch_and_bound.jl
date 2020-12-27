@testset "optimize!" begin
    fm = _build_dmip_formulation()
    config = Cerberus.AlgorithmConfig(silent = true)
    result = @inferred Cerberus.optimize!(fm, config)
    @test result.primal_bound ≈ 0.1 / 2.1
    @test result.dual_bound ≈ 0.1 / 2.1
    @test length(result.best_solution) == 3
    @test result.best_solution[_VI(1)] ≈ 1.0
    @test result.best_solution[_VI(2)] ≈ 2 / 2.1
    @test result.best_solution[_VI(3)] ≈ 0.0
    @test result.termination_status == Cerberus.OPTIMAL
    @test result.total_node_count == 3
    @test result.total_simplex_iters == 0
end

@testset "process_node!" begin
    # A feasible model
    let
        fm = _build_dmip_formulation()
        state = Cerberus.CurrentState()
        node = Cerberus.Node()
        config = Cerberus.AlgorithmConfig(silent = true)
        @inferred Cerberus.process_node!(state, fm, node, config)
        result = state.node_result
        @test result.cost ≈ 0.5 - 2.5 / 2.1
        @test result.simplex_iters == 0
        @test length(result.x) == 3
        @test result.x[_VI(1)] ≈ 0.5
        @test result.x[_VI(2)] ≈ 2.5 / 2.1
        @test result.x[_VI(3)] ≈ 0.0
        @test result.basis == Cerberus.Basis(
            _CI{_SV,_IN}(1) => MOI.NONBASIC_AT_LOWER,
            _CI{_SV,_IN}(2) => MOI.BASIC,
            _CI{_SV,_IN}(3) => MOI.NONBASIC_AT_LOWER,
            _CI{_SAF,_ET}(2) => MOI.NONBASIC,
            _CI{_SAF,_LT}(3) => MOI.BASIC,
        )
        @test result.model === nothing
    end

    # An infeasible model
    let
        fm = _build_dmip_formulation()
        state = Cerberus.CurrentState()
        # A bit hacky, but force infeasibility by branching both up and down.
        node = Cerberus.Node([
            Cerberus.BranchingDecision(_VI(1), 0, Cerberus.DOWN_BRANCH),
            Cerberus.BranchingDecision(_VI(1), 1, Cerberus.UP_BRANCH),
        ])
        config = Cerberus.AlgorithmConfig(silent = true)
        @inferred Cerberus.process_node!(state, fm, node, config)
        result = state.node_result
        @test result.cost == Inf
        @test result.simplex_iters == 0
        @test isempty(result.x)
        @test isempty(result.basis)
        @test result.model === nothing
    end
end

@testset "_ip_feasible" begin
    config = Cerberus.AlgorithmConfig()
    let fm = _build_dmip_formulation()
        x_int = Dict(_VI(1) => 1.0, _VI(2) => 3.2, _VI(3) => 0.0)
        @test Cerberus._ip_feasible(fm, x_int, config)
        x_int_2 = Dict(
            _VI(1) => 1.0 - 0.9config.int_tol,
            _VI(2) => 3.2,
            _VI(3) => 0.0 + 0.9config.int_tol,
        )
        @test Cerberus._ip_feasible(fm, x_int_2, config)
        x_int_3 = Dict(
            _VI(1) => 1.0 - 2config.int_tol,
            _VI(2) => 3.2,
            _VI(3) => 0.0 + config.int_tol,
        )
        @test !Cerberus._ip_feasible(fm, x_int_3, config)
    end

    let fm = _build_gi_dmip_formulation()
        x_int = Dict(_VI(1) => 0.6, _VI(2) => 0.0, _VI(3) => 2.0)
        @test Cerberus._ip_feasible(fm, x_int, config)
        x_int[_VI(2)] = 0.9
        @test !Cerberus._ip_feasible(fm, x_int, config)
        x_int[_VI(2)] = 1.0
        x_int[_VI(3)] = 3.0
        @test Cerberus._ip_feasible(fm, x_int, config)
        x_int[_VI(2)] = 1.0
        x_int[_VI(3)] = 2.9
        @test !Cerberus._ip_feasible(fm, x_int, config)
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
    result = Cerberus.NodeResult(
        12.3,
        1492,
        _vec_to_dict([1.2, 2.3, 3.4]),
        basis,
        model,
    )
    @inferred Cerberus._attach_parent_info!(fc, oc, result)
    @test fc.parent_info == Cerberus.ParentInfo(12.3, basis, model)
    @test oc.parent_info == Cerberus.ParentInfo(12.3, basis, nothing)
end

@testset "update_state!" begin
    fm = _build_dmip_formulation()
    config = Cerberus.AlgorithmConfig()
    starting_pb = 12.3
    simplex_iters_per = 18
    cs = Cerberus.CurrentState(starting_pb)
    @test _is_root_node(Cerberus.pop_node!(cs.tree))
    node = Cerberus.Node()

    # 1. Prune by infeasibility
    nr1 = Cerberus.NodeResult()
    cs.node_result.cost = Inf
    cs.node_result.simplex_iters = simplex_iters_per
    @inferred Cerberus.update_state!(cs, fm, node, config)
    @test isempty(cs.tree)
    @test cs.total_node_count == 1
    @test cs.primal_bound == starting_pb
    @test cs.dual_bound == -Inf
    @test isempty(cs.best_solution)
    @test cs.total_simplex_iters == simplex_iters_per

    # 2. Prune by bound
    frac_soln = [0.2, 3.4, 0.6]
    empty!(cs.node_result)
    cs.node_result.cost = 13.5
    cs.node_result.simplex_iters = simplex_iters_per
    cs.node_result.x = _vec_to_dict(frac_soln)
    @inferred Cerberus.update_state!(cs, fm, node, config)
    @test isempty(cs.tree)
    @test cs.total_node_count == 2
    @test cs.primal_bound == starting_pb
    @test cs.dual_bound == -Inf
    @test isempty(cs.best_solution)
    @test cs.total_simplex_iters == 2 * simplex_iters_per

    # 3. Prune by integrality
    int_soln = [1.0, 3.4, 0.0]
    int_soln_dict = _vec_to_dict(int_soln)
    new_pb = 11.1
    empty!(cs.node_result)
    cs.node_result.cost = new_pb
    cs.node_result.simplex_iters = simplex_iters_per
    cs.node_result.x = copy(int_soln_dict)
    @inferred Cerberus.update_state!(cs, fm, node, config)
    @test isempty(cs.tree)
    @test cs.total_node_count == 3
    @test cs.primal_bound == new_pb
    @test cs.dual_bound == -Inf
    @test cs.best_solution == int_soln_dict
    @test cs.total_simplex_iters == 3 * simplex_iters_per

    # 4. Branch
    frac_soln_2 = [0.0, 2.9, 0.6]
    frac_soln_dict = _vec_to_dict(frac_soln_2)
    db = 10.1
    basis = Cerberus.Basis(_CI{_SV,_IN}(1) => MOI.BASIC)
    model = Gurobi.Optimizer()
    empty!(cs.node_result)
    cs.node_result.cost = 10.1
    cs.node_result.simplex_iters = simplex_iters_per
    cs.node_result.x = frac_soln_dict
    cs.node_result.basis = basis
    cs.node_result.model = model
    @inferred Cerberus.update_state!(cs, fm, node, config)
    @test Cerberus.num_open_nodes(cs.tree) == 2
    @test cs.total_node_count == 4
    @test cs.primal_bound == new_pb
    @test cs.dual_bound == -Inf
    @test cs.best_solution == int_soln_dict
    @test cs.total_simplex_iters == 4 * simplex_iters_per
    @inferred Cerberus.update_dual_bound!(cs)
    @test cs.dual_bound == db
    fc = Cerberus.pop_node!(cs.tree)
    @test fc.branchings ==
          [Cerberus.BranchingDecision(_VI(3), 1, Cerberus.UP_BRANCH)]
    @test fc.parent_info.dual_bound == db
    @test fc.parent_info.basis == basis
    @test fc.parent_info.hot_start_model === model
    oc = Cerberus.pop_node!(cs.tree)
    @test oc.branchings ==
          [Cerberus.BranchingDecision(_VI(3), 0, Cerberus.DOWN_BRANCH)]
    @test oc.parent_info.dual_bound == db
    @test oc.parent_info.basis == basis
    @test oc.parent_info.hot_start_model === nothing
end
