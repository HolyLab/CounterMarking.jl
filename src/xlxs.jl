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
