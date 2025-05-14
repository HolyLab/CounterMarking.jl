"""
    randshow(seg; kwargs...)

Display a segmented image using random colors for each segment.

!!! note
    You must load the `ImageView` package to use this function.
"""
function randshow end

"""
    meanshow(seg; kwargs...)

Display a segmented image using the mean color of each segment.

!!! note
    You must load the `ImageView` package to use this function.
"""
function meanshow end

function __init__()
    Base.Experimental.register_error_hint(MethodError) do io, exc, _, _
        if exc.f ∈ (randshow, meanshow)
            if isempty(methods(exc.f))
                printstyled(io, "\nYou may need `using ImageView` to load the appropriate methods."; color=:yellow)
            end
        end
    end
end
