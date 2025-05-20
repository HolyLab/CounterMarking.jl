module CounterMarkingImageViewExt

using CounterMarking: CounterMarking
using ImageCore
using ImageSegmentation
using ImageView
using Random

# function colorize(seg, segidxs::AbstractSet{Int}, color::Colorant)
#     label = seg.image_indexmap
#     img = similar(label, promote_type(typeof(color), valtype(seg.segment_means)))
#     fill!(img, zero(eltype(img)))
#     for idx in eachindex(label)
#         label[idx] ∈ segidxs || continue
#         img[idx] = color
#     end
#     return img
# end

function linkpair(img, imgc)
    zr, slicedata = roi(img)
    gd = imshow_gui((800, 800), (2,1); slicedata=slicedata)
    imshow(gd["frame"][1,1], gd["canvas"][1,1], img, nothing, zr, slicedata)
    imshow(gd["frame"][2,1], gd["canvas"][2,1], imgc, nothing, zr, slicedata)
    return gd
end

# For visualization
function get_random_color(seed)
    Random.seed!(seed)
    rand(RGB{N0f8})
end

CounterMarking.randshow(seg; kwargs...) = imshow(map(i->get_random_color(i), labels_map(seg)); kwargs...)
CounterMarking.meanshow(seg; kwargs...) = imshow(map(i->segment_mean(seg, i), labels_map(seg)); kwargs...)

CounterMarking.randshow(img, seg; kwargs...) = linkpair(img, map(i->get_random_color(i), labels_map(seg)); kwargs...)
CounterMarking.meanshow(img, seg; kwargs...) = linkpair(img, map(i->segment_mean(seg, i), labels_map(seg)); kwargs...)

end
