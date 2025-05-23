function makesheet!(sheet::XLSX.Worksheet, spotdict::AbstractDict{Int,Spot}, stimulus, imgsize)
    spotdict_ul, stimulus_ul = upperleft(spotdict, stimulus, imgsize)
    sd = collect(spotdict)
    p = sortperm(sd, by = x -> x.second.centroid[2])
    keyp = [sd[i].first for i in p]

    sheet["A1"] = "Spot"
    sheet["B1"] = "Centroid-x, raw"
    sheet["C1"] = "Centroid-y, raw"
    sheet["D1"] = "Centroid-x, UL"
    sheet["E1"] = "Centroid-y, UL"
    sheet["F1"] = "npixels"
    sheet["A2", dim=1] = vcat("Stimulus", [string(i) for i in 1:length(spotdict)])
    sheet["B2", dim=1] = vcat(stimulus.second.centroid[2], [sd[i].second.centroid[2] for i in p])
    sheet["C2", dim=1] = vcat(stimulus.second.centroid[1], [sd[i].second.centroid[1] for i in p])
    sheet["D2", dim=1] = vcat(stimulus_ul.second.centroid[2], [spotdict_ul[k].centroid[2] for k in keyp])
    sheet["E2", dim=1] = vcat(stimulus_ul.second.centroid[1], [spotdict_ul[k].centroid[1] for k in keyp])
    sheet["F2", dim=1] = vcat(stimulus.second.npixels, [sd[i].second.npixels for i in p])
end

function writexlsx(filename::AbstractString, spotdict::AbstractDict{Int,Spot}, stimulus, imgsize)
    XLSX.openxlsx(filename; mode="w") do xf
        sheet = xf[1]
        makesheet!(sheet, spotdict, stimulus, imgsize)
    end
    return
end

"""
    writexlsx(filename::AbstractString, seg::SegmentedImage)

Save the segmented image data to an Excel file.
"""
function writexlsx(filename::AbstractString, seg::SegmentedImage)
    imgsize = size(labels_map(seg))
    spotdict, stimulus = spots(seg)
    writexlsx(filename, spotdict, stimulus, imgsize)
end

"""
    process_images(outfile::AbstractString, glob::GlobMatch; dirname=pwd())
    process_images(outfile::AbstractString, glob::AbstractString; dirname=pwd())

Process all images with filenames matching `glob` and save the results to `outfile`.
Each image will be a separate sheet in the Excel file.

Optionally specify the `dirname` containing the images.

# Examples

To process a collection of images in a different directory, and save the results to
that same directory:

```julia
julia> process_images("2025-03-15/results.xlsx", glob"*.png"; dirname="2025-03-15")
```
"""
function process_images(outfile::AbstractString, glob::Glob.GlobMatch; dirname=pwd())
    i = 0
    XLSX.openxlsx(outfile; mode="w") do xf
        for filename in readdir(glob, dirname)
            img = load(filename)
            seg = segment_image(img)
            imgsize = size(labels_map(seg))
            spotdict, stimulus = spots(seg)
            sheetname = splitext(basename(filename))[1]
            sheet = if i == 0
                i += 1
                XLSX.rename!(xf[1], sheetname)
                xf[1]
            else
                XLSX.addsheet!(xf, sheetname)
            end
            makesheet!(sheet, spotdict, stimulus, imgsize)
        end
    end
end
process_images(outfile::AbstractString, glob::AbstractString; kwargs...) =
    process_images(outfile, Glob.GlobMatch(glob); kwargs...)
