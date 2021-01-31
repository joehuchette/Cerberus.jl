function _build_disjunction()
    form = Cerberus.DMIPFormulation()
    Cerberus.add_variable(form)
    Cerberus.add_variable(form)
    form.feasible_region.bounds = [_IN(-1.1, 1.1), _IN(-1.1, 1.1)]
    x = [_SV(_VI(1)), _SV(_VI(2))]
    Cerberus.add_constraint(form.feasible_region, Cerberus.AffineConstraint(1.0 * x[1] + 1.0 * x[2], _LT(0.5)))
    Cerberus.add_constraint(form.feasible_region, Cerberus.AffineConstraint(1.0 * x[1] - 1.0 * x[2], _LT(0.6)))

    f_1 = 1.0 * x[1] + 1.0 * x[2]
    f_2 = 1.0 * x[1] - 1.0 * x[2]
    f_3 = 1.0 * x[1] + 0.5 * x[2]
    f_4 = 1.0 * x[1] - 0.5 * x[2]
    f = MOIU.vectorize([f_1, f_2, f_3, f_4])

    lbs = [
        -Inf -Inf -Inf
        -Inf -Inf -Inf
        -Inf -Inf 0.5
        -Inf -Inf 0.5
    ]
    ubs = [
        0.0 Inf Inf
        Inf 0.0 Inf
        Inf Inf Inf
        Inf Inf Inf
    ]
    s = DisjunctiveConstraints.DisjunctiveSet(lbs, ubs)
    return form, DisjunctiveConstraints.Disjunction(f, s)
end

@testset "NaiveBigMFormulater" begin
    form, disjunction = _build_disjunction()
    activity_method = DisjunctiveConstraints.IntervalArithmetic()
    formulater = Cerberus.NaiveBigMFormulater(disjunction, activity_method)

    @testset "new_variables_to_attach" begin
        raw_indices = Cerberus.new_variables_to_attach(formulater)
        @test raw_indices == [_ZO(), _ZO(), _ZO()]
        for var_kind in raw_indices
            Cerberus.add_variable(form, var_kind)
        end
    end
    @testset "compute_disjunction_activity" begin
        let node = Cerberus.Node()
            pa, ni = Cerberus.compute_disjunction_activity(form, [3,4,5], node)
            @test pa == [false, false, false]
            @test ni == [true, true, true]
        end
        let node = Cerberus.Node(Cerberus.BoundDiff(_VI(3) => 1.0), Cerberus.BoundDiff(_VI(5) => 0.0), 2)
            pa, ni = Cerberus.compute_disjunction_activity(form, [3,4,5], node)
            @test pa == [true, false, false]
            @test ni == [true, true, false]
        end
    end
end

@testset "formulate! for NaiveBigMFormulater" begin
    form = _build_dmip_formulation()
    state = Cerberus.CurrentState(form)
    # TODO: Finish these tests...
end
