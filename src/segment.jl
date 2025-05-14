"""
    seg = segment_image(img; threshold=0.1, min_size=20)

Given an image `img`, segment it into regions using a region growing algorithm.
`min_size` is the minimum number of pixels per segment, and `threshold` determines
how different two colors must be to be considered different segments.
Larger `threshold` values will result in fewer segments.
"""
function segment_image(
        img::AbstractMatrix{<:Color};
        threshold::Real = 0.2,      # threshold for color similarity in region growing
        prune::Bool = true,         # prune small segments
        min_size::Int = 50,         # minimum size of segments to keep
    )
    seg = unseeded_region_growing(img, threshold)
    L = label_components(labels_map(seg))   # insist on contiguous regions
    seg = SegmentedImage(img, L)
    if prune
        println("Pruning segments smaller than $min_size pixels")
        seg = prune_segments(seg, label -> segment_pixel_count(seg, label) < min_size, (l1, l2) -> colordiff(segment_mean(seg, l1), segment_mean(seg, l2)))
    end
    return seg
end
segment_image(img::AbstractMatrix{<:Colorant}; kwargs...) = segment_image(color.(img); kwargs...)

"""
    idx = stimulus_index(seg::SegmentedImage, colorproj = RGB(1, 1, -2))

Given a segmented image `seg`, return the index of the segment that scores
highest on the product of (1) projection (dot product) with `colorproj` and (2)
number of pixels.
"""
function stimulus_index(seg::SegmentedImage, colorproj = RGB{Float32}(1, 1, -2))
    proj = [l => (colorproj ⋅ segment_mean(seg, l)) * segment_pixel_count(seg, l) for l in segment_labels(seg)]
    (i, _) = argmax(last, proj)
    return i
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
        seg;
        max_size_frac=0.1,            # no spot is bigger than max_size_frac * npixels
    )
    keypair(i, j) = i < j ? (i, j) : (j, i)

    istim = stimulus_index(seg)

    label = seg.image_indexmap
    R = CartesianIndices(label)
    Ibegin, Iend = extrema(R)
    I1 = one(Ibegin)
    centroidsacc = Dict{Int, Tuple{Int, Int, Int}}()   # accumulator for centroids
    nadj = Dict{Tuple{Int, Int}, Int}()             # number of times two segments are adjacent
    for idx in R
        l = label[idx]
        l == 0 && continue
        acc = get(centroidsacc, l, (0, 0, 0))
        centroidsacc[l] = (acc[1] + idx[1], acc[2] + idx[2], acc[3] + 1)
        for j in max(Ibegin, idx - I1):min(Iend, idx + I1)
            lj = label[j]
            if lj != l && lj != 0
                k = keypair(l, lj)
                nadj[k] = get(nadj, k, 0) + 1
            end
        end
    end
    stimulus = Ref{Pair{Int,Spot}}()
    filter!(centroidsacc) do (key, val)
        if key == istim
            stimulus[] = key => Spot(val[3], (round(Int, val[1] / val[3]), round(Int, val[2] / val[3])))
            return false
        end
        val[3] <= max_size_frac * length(label) || return false
        # # is the centroid within the segment?
        # x, y = round(Int, val[1] / val[3]), round(Int, val[2] / val[3])
        # l = label[x, y]
        # @show l
        # l == key || return false
        # is the segment lighter than most of its neighbors?
        dcol, ncol = zero(valtype(seg.segment_means)), 0
        for (k, n) in nadj
            if key == k[1] || key == k[2]
                l1, l2 = k[1], k[2]
                if l1 == key
                    l1, l2 = l2, l1
                end
                dcol += n * (segment_mean(seg, l1) - segment_mean(seg, l2))
                ncol += n
            end
        end
        return reducec(+, dcol) < 0
    end
    return Dict(l => Spot(val[3], (round(Int, val[1] / val[3]), round(Int, val[2] / val[3]))) for (l, val) in centroidsacc), stimulus[]
end

"""
    spotdict, stimulus = upperleft(spotdict::AbstractDict{Int, Spot}, stimulus, imgsize)

Given a `spotdict` of `Spot` objects and a `stimulus` segment, return a new
`spotdict` where the centroids of the spots are flipped so that the stimlus spot
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
