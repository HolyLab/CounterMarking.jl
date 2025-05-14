module CounterMarking

using ImageCore
using ImageSegmentation
using ImageMorphology: label_components
using FileIO

export segment_image, stimulus_index, spots, Spot, upperleft
export randshow, meanshow

include("segment.jl")
include("stubs.jl")

end
