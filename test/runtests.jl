using CounterMarking
using FileIO
using XLSX
using Test

@testset "CounterMarking.jl" begin
    testdir = joinpath(@__DIR__, "..", "docs", "src", "assets")
    img = load(joinpath(testdir, "Picture.png"))
    seg = segment_image(img)
    # Without ImageView loaded, we can't visualize it, but we get a helpful error
    if !isdefined(@__MODULE__, :ImageView)
        @test_throws "using ImageView" randshow(seg)
        @test_throws "using ImageView" meanshow(seg)
    end
    @eval using ImageView
    dct = meanshow(seg)
    @test haskey(dct, "gui")
    dct = randshow(seg)
    @test haskey(dct, "gui")
    dct = randshow(img, seg)
    @test haskey(dct, "window")
    dct = meanshow(img, seg)
    @test haskey(dct, "window")
    ImageView.closeall()

    spotdict, stimulus = spots(seg)
    _, stimspot = stimulus
    @test stimspot.npixels > 1000
    @test stimspot.centroid[1] < size(img, 1) ÷ 2
    @test stimspot.centroid[2] > size(img, 2) ÷ 2

    stdspotdict, stdstimulus = upperleft(spotdict, stimulus, size(img))
    _, stimspot = stdstimulus
    @test stimspot.npixels > 1000
    @test stimspot.centroid[1] < size(img, 1) ÷ 2
    @test stimspot.centroid[2] < size(img, 2) ÷ 2

    # Test the xlsx writing
    tmpfile = tempname() * ".xlsx"
    writexlsx(tmpfile, seg)
    @test isfile(tmpfile)

    # Test multi-file writing
    process_images(tmpfile, glob"*.png"; dirname=testdir)
    data = XLSX.readtable(tmpfile, "Picture")
    @test isa(data, XLSX.DataTable)
end
