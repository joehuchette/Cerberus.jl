@testset "AffineConstraint" begin
    v = [_SV(_VI(i)) for i in 1:3]
    ac = Cerberus.AffineConstraint(v[1] + 2.0 * v[2] + 3.0 * v[3], _ET(3.0))
    @test typeof(ac.f) == _SAF
    @test ac.f.terms == [
        MOI.ScalarAffineTerm{Float64}(2.0, _VI(2)),
        MOI.ScalarAffineTerm{Float64}(1.0, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(3.0, _VI(3)),
    ]
    @test ac.f.constant == 0.0
    @test ac.s == _ET(3.0)
end

function _test_polyhedron(p::Cerberus.Polyhedron)
    @test Cerberus.num_constraints(p) == 2
    @test Cerberus.num_constraints(p, _LT) == length(p.lt_constrs) == 1
    @test Cerberus.num_constraints(p, _GT) == length(p.gt_constrs) == 0
    @test Cerberus.num_constraints(p, _ET) == length(p.et_constrs) == 1
    et_constr = @inferred Cerberus.get_constraint(p, _ET, 1)
    @test et_constr === p.et_constrs[1]
    @test et_constr.f.terms == [
        MOI.ScalarAffineTerm{Float64}(2.1, _VI(2)),
        MOI.ScalarAffineTerm{Float64}(1.0, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(3.0, _VI(3)),
    ]
    @test et_constr.f.constant == 0.0
    @test et_constr.s == _ET(3.0)

    lt_constr = @inferred Cerberus.get_constraint(p, _LT, 1)
    @test lt_constr === p.lt_constrs[1]
    @test lt_constr.f.terms == [
        MOI.ScalarAffineTerm{Float64}(-3.5, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(1.2, _VI(2)),
    ]
    @test lt_constr.f.constant == 0.0
    @test lt_constr.s == _LT(4.0)

    @test p.bounds == [_IN(0.5, 1.0), _IN(-1.3, 2.3), _IN(0.0, 1.0)]

    return nothing
end

@testset "Polyhedron" begin
    p = @inferred _build_polyhedron()
    _test_polyhedron(p)

    # TODO: Test throws on malformed Polyhedron
    @test_throws AssertionError Cerberus.Polyhedron(
        [
            Cerberus.AffineConstraint(
                1.0 * _SV(_VI(1)) + 2.0 * _SV(_VI(2)),
                _ET(1.0),
            ),
        ],
        [_IN(0.0, 1.0)],
    )
    @testset "ambient_dim" begin
        @test Cerberus.ambient_dim(p) == 3
    end
    @testset "num_constraints" begin
        @test Cerberus.num_constraints(p) == 2
    end
    @testset "add_variable" begin
        Cerberus.add_variable(p)
        @test Cerberus.ambient_dim(p) == 4
    end
    @testset "empty constructor" begin
        p = @inferred Cerberus.Polyhedron()
        @test Cerberus.ambient_dim(p) == 0
        @test Cerberus.num_constraints(p) == 0
    end
end

@testset "DMIPFormulation" begin
    fm = @inferred _build_dmip_formulation()
    _test_polyhedron(fm.feasible_region)
    @test typeof(fm.obj) == _SAF
    @test fm.obj.terms == [
        MOI.ScalarAffineTerm{Float64}(1.0, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(-1.0, _VI(2)),
    ]
    @test fm.obj.constant == 0.0
    @test isempty(fm.disjunction_formulaters)
    @test fm.integrality == [_ZO(), nothing, _ZO()]

    @testset "empty constructor" begin
        fm = @inferred Cerberus.DMIPFormulation()
        @test Cerberus.num_variables(fm) == 0
        @test Cerberus.ambient_dim(fm.feasible_region) == 0
        @test Cerberus.num_constraints(fm.feasible_region) == 0
        @test isempty(fm.obj.terms)
        @test fm.obj.constant == 0.0
        @test isempty(fm.disjunction_formulaters)
        @test isempty(fm.integrality)
    end

    # TODO: Test throws on malformed DMIPFormulation
end

function _test_gi_polyhedron(p::Cerberus.Polyhedron)
    @test Cerberus.num_constraints(p) == 1
    @test Cerberus.num_constraints(p, _LT) == 1
    @test Cerberus.num_constraints(p, _GT) == 0
    @test Cerberus.num_constraints(p, _ET) == 0
    lt_constr = @inferred Cerberus.get_constraint(p, _LT, 1)
    @test lt_constr === p.lt_constrs[1]
    @test lt_constr.f.terms == [
        MOI.ScalarAffineTerm{Float64}(1.3, _VI(1)),
        MOI.ScalarAffineTerm{Float64}(3.7, _VI(2)),
        MOI.ScalarAffineTerm{Float64}(2.4, _VI(3)),
    ]
    @test lt_constr.f.constant == 0.0
    @test lt_constr.s == _LT(5.5)

    @test p.bounds == [_IN(0.0, 4.5), _IN(0.0, 1.0), _IN(0.0, 3.0)]
end

@testset "General integer polyhedron/formulation" begin
    p = @inferred _build_gi_polyhedron()
    _test_gi_polyhedron(p)

    fm = @inferred _build_gi_dmip_formulation()
    _test_gi_polyhedron(fm.feasible_region)
    @test isempty(fm.disjunction_formulaters)
    @test fm.integrality == [nothing, _ZO(), _GI()]
end
