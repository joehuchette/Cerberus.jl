@testset "NodeResult" begin
    cost = 5.6
    x = [1.2, 3.4]
    simplex_iters = 3
    depth = 12
    int_infeas = 4
    let nr1 = @inferred Cerberus.NodeResult(
            cost,
            x,
            simplex_iters,
            depth,
            int_infeas,
        )
        @test nr1.cost == cost
        @test nr1.x == x
        @test nr1.simplex_iters == simplex_iters
        @test nr1.depth == depth
        @test nr1.int_infeas == int_infeas
    end
end

@testset "CurrentState" begin
    fm = _build_dmip_formulation()

    nvars = Cerberus.num_variables(fm)
    pb_float = 12.4
    pb_int = 12

    cs1 = @inferred _CurrentState(fm, CONFIG)
    cs2 = @inferred _CurrentState(fm, CONFIG, primal_bound = pb_float)
    cs3 = @inferred _CurrentState(fm, CONFIG, primal_bound = pb_int)

    @test length(cs1.tree) == 1
    @test length(cs2.tree) == 1
    @test length(cs3.tree) == 1

    @test _is_root_node(Cerberus.pop_node!(cs1.tree))
    @test _is_root_node(Cerberus.pop_node!(cs2.tree))
    @test _is_root_node(Cerberus.pop_node!(cs3.tree))

    @test cs1.primal_bound == Inf
    @test cs2.primal_bound == pb_float
    @test cs3.primal_bound == pb_int

    @test cs1.dual_bound == -Inf
    @test cs2.dual_bound == -Inf
    @test cs3.dual_bound == -Inf

    @test length(cs1.best_solution) == nvars
    @test length(cs2.best_solution) == nvars
    @test length(cs3.best_solution) == nvars
    @test all(isnan, values(cs1.best_solution))
    @test all(isnan, values(cs2.best_solution))
    @test all(isnan, values(cs3.best_solution))

    @test cs1.total_node_count == 0
    @test cs2.total_node_count == 0
    @test cs3.total_node_count == 0

    @test cs1.total_simplex_iters == 0
    @test cs2.total_simplex_iters == 0
    @test cs3.total_simplex_iters == 0
end

@testset "copy(::Basis)" begin
    src = _Basis(
        Dict(
            _CI{_SV,_IN}(1) => MOI.NONBASIC_AT_LOWER,
            _CI{_SV,_IN}(2) => MOI.BASIC,
            _CI{_SV,_IN}(3) => MOI.NONBASIC_AT_LOWER,
            _CI{_SAF,_ET}(3) => MOI.NONBASIC,
            _CI{_SAF,_LT}(2) => MOI.BASIC,
        ),
    )
    dest = copy(src)
    @test src.lt_constrs == dest.lt_constrs
    @test src.gt_constrs == dest.gt_constrs
    @test src.et_constrs == dest.et_constrs
    @test src.var_constrs == dest.var_constrs
    empty!(src.lt_constrs)
    empty!(src.gt_constrs)
    empty!(src.et_constrs)
    empty!(src.var_constrs)
    @test dest.lt_constrs == Dict(_CI{_SAF,_LT}(2) => MOI.BASIC)
    @test isempty(dest.gt_constrs)
    @test dest.et_constrs == Dict(_CI{_SAF,_ET}(3) => MOI.NONBASIC)
    @test dest.var_constrs == Dict(
        _CI{_SV,_IN}(1) => MOI.NONBASIC_AT_LOWER,
        _CI{_SV,_IN}(2) => MOI.BASIC,
        _CI{_SV,_IN}(3) => MOI.NONBASIC_AT_LOWER,
    )
end
