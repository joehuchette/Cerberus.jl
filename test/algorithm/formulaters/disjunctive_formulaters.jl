# @testset "copy_with_new_variable_indices" begin
#     new_vis = [_VI(12), _VI(24), _VI(48)]
#     let f = _VOV([_VI(1), _VI(3), _VI(2)])
#         f_expected = _VOV([_VI(12), _VI(48), _VI(24)])
#         f_actual =
#             @inferred Cerberus._copy_with_new_variable_indices(f, new_vis)
#         @test f_expected.variables == f_actual.variables
#     end
#     let
#         f_1 = 2.0 * _SV(_VI(1)) + 4.0 * _SV(_VI(3))
#         f_2 = 6.0 * _SV(_VI(2)) + 8.0 * _SV(_VI(1))
#         f = MOIU.vectorize([f_1, f_2])
#         f_expected = MOIU.vectorize([
#             2.0 * _SV(_VI(12)) + 4.0 * _SV(_VI(48)),
#             6.0 * _SV(_VI(24)) + 8.0 * _SV(_VI(12)),
#         ])
#         f_actual =
#             @inferred Cerberus._copy_with_new_variable_indices(f, new_vis)
#         f_actual_scalar = MOIU.scalarize(f_actual)
#         @test length(f_actual_scalar) == 2
#         @test _is_equal(
#             f_actual_scalar[1],
#             2.0 * _SV(_VI(12)) + 4.0 * _SV(_VI(48)),
#         )
#         @test _is_equal(
#             f_actual_scalar[2],
#             6.0 * _SV(_VI(24)) + 8.0 * _SV(_VI(12)),
#         )
#     end
# end

# @testset "mask_and_update_variable_indices" begin
#     new_vis = [_VI(13), _VI(26), _VI(39)]
#     let
#         f = _VOV([_VI(1), _VI(3), _VI(2)])
#         lbs = [
#             -1.0 -2.0 -3.0 -4.0
#             -1.0 -2.0 -3.0 -4.0
#             -1.0 -2.0 -3.0 -4.0
#         ]
#         ubs = [
#             1.0 2.0 3.0 4.0
#             1.0 2.0 3.0 4.0
#             1.0 2.0 3.0 4.0
#         ]
#         s = DisjunctiveConstraints.DisjunctiveSet(lbs, ubs)
#         model_disj = DisjunctiveConstraints.Disjunction(f, s)
#         mask = [true, false, false, true]
#         masked_disj = @inferred Cerberus.mask_and_update_variable_indices(
#             model_disj,
#             new_vis,
#             mask,
#         )
#         @test masked_disj.f == _VOV([_VI(13), _VI(39), _VI(26)])
#         @test masked_disj.s.lbs == lbs[:, mask]
#         @test masked_disj.s.ubs == ubs[:, mask]
#     end
#     let
#         f_1 = 2.0 * _SV(_VI(1)) + 4.0 * _SV(_VI(3))
#         f_2 = 6.0 * _SV(_VI(2)) + 8.0 * _SV(_VI(1))
#         f = MOIU.vectorize([f_1, f_2])
#         lbs = [
#             -1.0 -2.0 -3.0
#             -1.0 -2.0 -3.0
#         ]
#         ubs = [
#             1.0 2.0 3.0
#             1.0 2.0 3.0
#         ]
#         s = DisjunctiveConstraints.DisjunctiveSet(lbs, ubs)
#         model_disj = DisjunctiveConstraints.Disjunction(f, s)
#         mask = [false, false, true]
#         masked_disj = @inferred Cerberus.mask_and_update_variable_indices(
#             model_disj,
#             new_vis,
#             mask,
#         )
#         f_actual_scalar = MOIU.scalarize(masked_disj.f)
#         @test _is_equal(
#             f_actual_scalar[1],
#             2.0 * _SV(_VI(13)) + 4.0 * _SV(_VI(39)),
#         )
#         @test _is_equal(
#             f_actual_scalar[2],
#             6.0 * _SV(_VI(26)) + 8.0 * _SV(_VI(13)),
#         )
#         @test masked_disj.s.lbs == lbs[:, mask]
#         @test masked_disj.s.ubs == ubs[:, mask]
#     end
# end
