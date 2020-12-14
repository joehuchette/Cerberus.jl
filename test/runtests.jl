using Test
using Cerberus
using SparseArrays

for (root, dirs, files) in walkdir(@__DIR__)
    for _file in filter(f -> endswith(f, ".jl"), files)
        file = relpath(joinpath(root, _file), @__DIR__)
        if file in ["runtests.jl"]
            continue
        end

        @testset "$(file)" begin
            include(file)
        end
    end
end
