module CounterMarking

using ImageCore
using ImageSegmentation
using ImageMorphology: label_components
using FileIO
using JLD2
using XLSX
using Glob
using Gtk4
using GtkObservables
using ImageView
using Random

export segment_image, stimulus_index, spots, Spot, upperleft
export writexlsx, process_images
export randshow, meanshow, gui

include("segment.jl")
include("xlxs.jl")
include("gui.jl")

end
