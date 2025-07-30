"""
    seg = segment_image(img; threshold=0.1, min_size=20)

Given an image `img`, segment it into regions using a region growing algorithm.
`min_size` is the minimum number of pixels per segment, and `threshold` determines
how different two colors must be to be considered different segments.
Larger `threshold` values will result in fewer segments.
"""
function segment_image(
        img::AbstractMatrix{<:Color};
        threshold::Real = 0.15,     # threshold for color similarity in region growing
        prune::Bool = true,         # prune small segments
        min_size::Int = 500,        # minimum size of segments to keep
    )
    seg = unseeded_region_growing(img, threshold)
    if prune
        # println("Pruning segments smaller than $min_size pixels")
        seg = prune_segments(seg, label -> segment_pixel_count(seg, label) < min_size, (l1, l2) -> colordiff(segment_mean(seg, l1), segment_mean(seg, l2)))
    end
    return seg
end
segment_image(img::AbstractMatrix{<:Colorant}; kwargs...) = segment_image(color.(img); kwargs...)

"""
    idx = stimulus_index(seg::SegmentedImage, centroidsacc; colorproj = RGB(1, 1, -2), expectedloc = nothing)

Given a segmented image `seg`, return the index of the segment that scores
highest on the product of (1) projection (dot product) with `colorproj` and (2)
number of pixels.

Optionally, if images were taken with a fixed location for the stimulus, a segment's score
is divided by the squared distance of its centroid (via `centroidsacc`) from the position given by `expectedloc`.
"""
function stimulus_index(seg::SegmentedImage, centroidsacc; colorproj = RGB{Float32}(1, 1, -2), expectedloc = nothing)
    if !isnothing(expectedloc)
        proj = map(segment_labels(seg)) do l
            l == 0 && return 0
            val = centroidsacc[l]
            centroid = [round(Int, val[1] / val[3]), round(Int, val[2] / val[3])]
            return l => (colorproj ⋅ segment_mean(seg, l) * segment_pixel_count(seg, l) / max(1, sum(abs2, centroid .- expectedloc)))
        end
        (i, _) = argmax(last, proj)
        return i
    else 
        proj = [l => (colorproj ⋅ segment_mean(seg, l)) * segment_pixel_count(seg, l) for l in segment_labels(seg)]
        (i, _) = argmax(last, proj)
        return i
    end
end

# function contiguous(seg::SegmentedImage, img::AbstractMatrix{<:Color}; min_size::Int = 50)
#     L = label_components(labels_map(seg))   # insist on contiguous regions
#     newseg = SegmentedImage(img, L)
#     newseg = prune_segments(newseg, label -> segment_pixel_count(newseg, label) < min_size, (l1, l2) -> colordiff(segment_mean(newseg, l1), segment_mean(newseg, l2)))
#     mapping = Dict(k => Set{Int}() for k in segment_labels(seg))
#     for (i, l) in pairs(seg.image_indexmap)
#         push!(mapping[l], newseg.image_indexmap[i])
#     end
#     return mapping
# end
# contiguous(seg::SegmentedImage, img::AbstractMatrix{<:Colorant}; kwargs...) =
#     contiguous(seg, color.(img); kwargs...)

"""
    centroidsacc, nadj = get_centroidsacc(seg::SegmentedImage)

Given a the index map `indexmap` of a segmented image, return an accumulator for each segment's centroid
as well as the number of times two segments are adjacent.
"""
function get_centroidsacc(indexmap::Matrix{Int64})
    keypair(i, j) = i < j ? (i, j) : (j, i)
    R = CartesianIndices(indexmap)
    Ibegin, Iend = extrema(R)
    I1 = oneunit(Ibegin)
    centroidsacc = Dict{Int, Tuple{Int, Int, Int}}()   # accumulator for centroids
    nadj = Dict{Tuple{Int, Int}, Int}()             # number of times two segments are adjacent
    for idx in R
        l = indexmap[idx]
        l == 0 && continue
        acc = get(centroidsacc, l, (0, 0, 0))
        centroidsacc[l] = (acc[1] + idx[1], acc[2] + idx[2], acc[3] + 1)
        for j in max(Ibegin, idx - I1):min(Iend, idx + I1)
            lj = indexmap[j]
            if lj != l && lj != 0
                k = keypair(l, lj)
                nadj[k] = get(nadj, k, 0) + 1
            end
        end
    end
    return centroidsacc, nadj
end

struct Spot
    npixels::Int
    centroid::Tuple{Int, Int}
end

"""
    spotdict, stimulus = spots(seg; max_size_frac=0.1)

Given a segmented image `seg`, return a `Dict(idx => spot)` where `idx` is the segment index
and `spot` is a `Spot` object where `spot.npixels` is the number of pixels in the segment
and `spot.centroid` is the centroid of the segment.

`stimulus` is a `Pair{Int, Spot}` where the first element is the index of the
stimulus segment and the second element is the `Spot` object for that segment.

Spots larger than `max_size_frac * npixels` (default: 10% of the image) are ignored.
"""
function spots(
        seg::SegmentedImage;
        max_size_frac=0.1,            # no spot is bigger than max_size_frac * npixels
        kwargs...
    )
    centroidsacc, nadj = get_centroidsacc(seg.image_indexmap)
    istim = stimulus_index(seg, centroidsacc; kwargs...)

    stimulus = Ref{Pair{Int,Spot}}()
    filter!(centroidsacc) do (key, val)
        if key == istim
            stimulus[] = key => Spot(val[3], (round(Int, val[1] / val[3]), round(Int, val[2] / val[3])))
            return false
        end
        return val[3] <= max_size_frac * length(seg.image_indexmap)
        # # is the centroid within the segment?
        # x, y = round(Int, val[1] / val[3]), round(Int, val[2] / val[3])
        # l = seg.image_indexmap[x, y]
        # @show l
        # l == key || return false
        # is the segment lighter than most of its neighbors?
        # dcol, ncol = zero(valtype(seg.segment_means)), 0
        # for (k, n) in nadj
        #     if key == k[1] || key == k[2]
        #         l1, l2 = k[1], k[2]
        #         if l1 == key
        #             l1, l2 = l2, l1
        #         end
        #         dcol += n * (segment_mean(seg, l1) - segment_mean(seg, l2))
        #         ncol += n
        #     end
        # end
        # return reducec(+, dcol) < 0
    end
    return Dict(l => Spot(val[3], (round(Int, val[1] / val[3]), round(Int, val[2] / val[3]))) for (l, val) in centroidsacc), stimulus[]
end

function spots(
        indexmap::Matrix{Int},
        istim::Int;
        max_size_frac=0.1, 
        kwargs...
    )
    centroidsacc, nadj = get_centroidsacc(indexmap)
    stimulus = Ref{Pair{Int,Spot}}()
    filter!(centroidsacc) do (key, val)
        if key == istim
            stimulus[] = key => Spot(val[3], (round(Int, val[1] / val[3]), round(Int, val[2] / val[3])))
            return false
        end
        return val[3] <= max_size_frac * length(indexmap)
    end
    return Dict(l => Spot(val[3], (round(Int, val[1] / val[3]), round(Int, val[2] / val[3]))) for (l, val) in centroidsacc), stimulus[]
end

"""
    spotdict_ul, stimulus_ul = upperleft(spotdict::AbstractDict{Int, Spot}, stimulus, imgsize)

Given a `spotdict` of `Spot` objects and a `stimulus` segment, return a new
`spotdict_ul` corresponding to an image flipped so that `stimulus_ul`
is in the upper left corner.
"""
function upperleft(spotdict::AbstractDict{Int, Spot}, stimulus, imgsize)
    sidx, ss = stimulus
    midpoint = imgsize .÷ 2
    c1, c2 = ss.centroid .< midpoint
    imsz1, imsz2 = imgsize

    function flip(spot::Spot)
        x1, x2 = spot.centroid
        return Spot(spot.npixels, (c1 * x1 + (1 - c1) * (imsz1 - x1), c2 * x2 + (1 - c2) * (imsz2 - x2)))
    end
    return Dict(k => flip(v) for (k, v) in spotdict), sidx => flip(ss)
end

# function colorize(seg::SegmentedImage, coloridx::AbstractDict, colors=distinguishable_colors(length(unique(values(coloridx)))))
#     label = seg.image_indexmap
#     img = similar(label, eltype(colors))
#     for idx in eachindex(label)
#         img[idx] = colors[coloridx[label[idx]]]
#     end
#     return img
# end

"""
    nmarked = density_map(jldfile::AbstractString)

Given a JLD2 file `jldfile` written by `gui`, return an array `nmarked` counting
of the number of images with a urine spot in each pixel. Before counting, the
images are flipped so that the stimulus segment is in the upper left corner.
"""
function density_map(jldfile::AbstractString)
    data = load(jldfile)
    fns, imgsizes = String[], Tuple{Int, Int}[]
    for (filename, (seg, _, _)) in data
        push!(fns, filename)
        imgsize = size(seg)
        push!(imgsizes, imgsize)
    end
    szcount = Dict{Tuple{Int, Int}, Int}()
    for sz in imgsizes
        szcount[sz] = get(szcount, sz, 0) + 1
    end
    imgsize, n = argmax(last, szcount)
    badfiles = fns[imgsizes .!= Ref(imgsize)]
    if n != length(data)
        if n == 1
            error("no dominant image size found in $jldfile")
        else
            @warn("Image sizes do not all match, skipping $badfiles")
        end
    end

    nmarked = zeros(Int, imgsize)
    midpoint = imgsize .÷ 2
    for (fn, (seg, _, stimulus)) in data
        fn ∈ badfiles && continue
        sidx, ss = stimulus
        if ss.centroid[1] > midpoint[1]
            seg = reverse(seg; dims=1)
        end
        if ss.centroid[2] > midpoint[2]
            seg = reverse(seg; dims=2)
        end
        nmarked .+= seg .∉ Ref((0, sidx))
    end
    return nmarked
end
