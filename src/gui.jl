


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

"""
    randshow(seg; kwargs...)
    randshow(img, seg; kwargs...)

Display a segmented image using random colors for each segment. The version with
`img` displays the original image and the segmented image one atop the other,
and zooming on one will zoom on the other.

!!! note You must load the `ImageView` package to use this function.
"""
function randshow end

"""
    meanshow(seg; kwargs...)
    meanshow(img, seg; kwargs...)

Display a segmented image using the mean color of each segment. The version with
`img` displays the original image and the segmented image one atop the other,
and zooming on one will zoom on the other.

!!! note
    You must load the `ImageView` package to use this function.
"""
function meanshow end


randshow(seg; kwargs...) = imshow(map(i->get_random_color(i), labels_map(seg)); kwargs...)
meanshow(seg; kwargs...) = imshow(map(i->segment_mean(seg, i), labels_map(seg)); kwargs...)

randshow(img, seg; kwargs...) = linkpair(img, map(i->get_random_color(i), labels_map(seg)); kwargs...)
meanshow(img, seg; kwargs...) = linkpair(img, map(i->segment_mean(seg, i), labels_map(seg)); kwargs...)
