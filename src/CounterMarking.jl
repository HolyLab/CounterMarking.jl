module CounterMarking

using ImageCore
using ImageSegmentation
using ImageMorphology: label_components
using FileIO
using XLSX
using Glob

export segment_image, stimulus_index, spots, Spot, upperleft
export writexlsx, process_images
export randshow, meanshow

include("segment.jl")
include("stubs.jl")
include("xlxs.jl")

end
