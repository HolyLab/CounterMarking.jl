# pixel distance for each spot
function spot_distances(spot_dict, stimulus)
    origin = stimulus[2].centroid
    dists = Float64[]
    for (i,s) in spot_dict
        push!(dists, sqrt(sum(abs2, s.centroid .- origin)))
    end
    return sort(dists)
end

# pixel distance for each pixel belonging to a mark
function pixel_distances(indexmap, stimulus)
    origin = stimulus[2].centroid
    dists = Float64[]
    for c in CartesianIndices(indexmap)
        if indexmap[c] != 0 && indexmap[c] != stimulus[1]
            push!(dists, sqrt(sum(abs2, Tuple(c) .- origin)))
        end
    end
    return sort(dists)
end