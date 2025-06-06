"""
    gui(outbase, files)
    gui(outbase, glob::GlobMatch)

Run the graphical user interface (GUI) for CounterMarking. Supply the base name
of the output files (e.g., "my_results") and a list of image files to process
(alternatively, supply a `glob"pattern"` that matches just the files you want to
process).

The GUI will display the images and their segmentation, and allow the user to
select the segments corresponding to the stimulus (yellow) and marked spots. The
results will be save to:

- `outbase.xlsx`: an Excel file with one sheet per image, containing summary
   statistics on the stimulus spot and the selected spots.
- `outbase.jld2`: a JLD2 file with one dataset per image, containing the
   segmented image, the selected spots, and the stimulus segment.

The JLD2 file can be used by [`density_map`](@ref).
"""
function gui(
        outbase::AbstractString, files;
        colors=distinguishable_colors(15, [RGB(1, 1, 1)]; dropseed=true),
        btnclick = Condition(),         # used for testing
        whichbutton = Ref{Symbol}(),    # used for testing
        preclick::Union{Int,Nothing} = nothing,  # used for testing
    )
    channelpct(x) = string(round(Int, x * 100)) * '%'

    outbase, _ = splitext(outbase)

    # Set up basic properties of the window
    winsize = round.(Int, 0.8 .* screen_size())
    win = GtkWindow("CounterMarking", winsize...)
    ag = Gtk4.GLib.GSimpleActionGroup()
    m = Gtk4.GLib.GActionMap(ag)
    push!(win, Gtk4.GLib.GActionGroup(ag), "win")
    Gtk4.GLib.add_action(m, "close", ImageView.close_cb, win)
    Gtk4.GLib.add_action(m, "closeall", ImageView.closeall_cb, nothing)
    Gtk4.GLib.add_stateful_action(m, "fullscreen", false, ImageView.fullscreen_cb, win)
    sc = GtkShortcutController(win)
    Gtk4.add_action_shortcut(sc,Sys.isapple() ? "<Meta>W" : "<Control>W", "win.close")
    Gtk4.add_action_shortcut(sc,Sys.isapple() ? "<Meta><Shift>W" : "<Control><Shift>W", "win.closeall")
    Gtk4.add_action_shortcut(sc,Sys.isapple() ? "<Meta><Shift>F" : "F11", "win.fullscreen")

    # CSS styling for the colors
    io = IOBuffer()
    for (i, color) in enumerate(colors)
        colorstr = "rgb(" * channelpct(color.r) * ", " *
                            channelpct(color.g) * ", " *
                            channelpct(color.b) * ")"
        println(io, """
        .color$i {
            background: $colorstr;
        }
        """)
    end
    css = String(take!(io))
    cssprov = GtkCssProvider(css)
    push!(Gtk4.display(win), cssprov)

    # Create the elements of the GUI
    win[] = bx = GtkBox(:v)
    ImageView.window_wrefs[win] = nothing
    signal_connect(win, :destroy) do w
        delete!(ImageView.window_wrefs, win)
    end
    g, frames, canvases = ImageView.canvasgrid((2, 1), :auto)
    push!(bx, g)
    push!(bx, GtkSeparator(:h))
    guibx = GtkBox(:h)
    push!(bx, guibx)
    seggrid = GtkGrid()
    push!(guibx, seggrid)
    # Add checkboxes for each color, with the box's color set to the color
    cbs = []
    for i in 1:length(colors)
        cb = checkbox(false)
        add_css_class(cb.widget, "color$i")
        for prop in ("margin_start", "margin_end", "margin_top", "margin_bottom")
            set_gtk_property!(cb.widget, prop, 5)
        end
        set_gtk_property!(cb.widget, "width-request", 20)
        row = div(i - 1, 5) + 1
        col = mod(i - 1, 5) + 1
        seggrid[col, row] = cb.widget
        push!(cbs, cb)
    end
    # Add "Done & Next" and "Skip" buttons
    donebtn = button("Done & Next")
    skipbtn = button("Skip")
    push!(guibx, donebtn)
    push!(guibx, skipbtn)
    on(donebtn) do _
        whichbutton[] = :done
        notify(btnclick)
    end
    on(skipbtn) do _
        whichbutton[] = :skip
        notify(btnclick)
    end

    results = []
    for (i, file) in enumerate(files)
        img = color.(load(file))
        seg = segment_image(img)
        nsegs = length(segment_labels(seg))
        @assert nsegs < length(colors) "Too many segments for colors"
        istim = stimulus_index(seg)
        for (j, cb) in enumerate(cbs)
            # set_gtk_property!(cb, "active", j <= nsegs)
            cb[] = (j == istim || j == preclick)
        end
        imshow(canvases[1, 1], img)
        imshow(canvases[2, 1], map(i->colors[i], labels_map(seg)))

        wait(btnclick)
        whichbutton[] == :skip && continue

        keep = Int[]
        for (j, cb) in enumerate(cbs)
            if cb[]
                push!(keep, j)
            end
        end
        pixelskeep = map(i -> i ∈ keep, labels_map(seg))
        L = label_components(pixelskeep)
        newseg = SegmentedImage(img, L)
        spotdict, stimulus = spots(newseg)
        push!(results, (file, spotdict, stimulus, newseg))
    end

    if !isempty(results)
        xlsxname = outbase * ".xlsx"
        XLSX.openxlsx(xlsxname; mode="w") do xf
            for (i, (file, spotdict, stimulus, seg)) in enumerate(results)
                imgsize = size(labels_map(seg))
                sheetname = splitext(basename(file))[1]
                sheet = if i == 1
                    XLSX.rename!(xf[1], sheetname)
                    xf[1]
                else
                    XLSX.addsheet!(xf, sheetname)
                end
                makesheet!(sheet, spotdict, stimulus, imgsize)
            end
        end
        jldname = outbase * ".jld2"
        jldopen(jldname, "w") do jf
            for (file, spotdict, stimulus, seg) in results
                imgname = splitext(basename(file))[1]
                write(jf, imgname, (labels_map(seg), spotdict, stimulus))
            end
        end
    end
    destroy(win)
    notify(btnclick)   # used in testing
    return
end
gui(outbase::AbstractString, glob::Glob.GlobMatch; kwargs...) = gui(outbase, Glob.glob(glob); kwargs...)

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
