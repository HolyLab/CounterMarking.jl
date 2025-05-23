using CounterMarking
using FileIO
using XLSX
using ImageView
using Glob
using Test

@testset "CounterMarking.jl" begin
    testdir = joinpath(pkgdir(CounterMarking), "docs", "src", "assets")
    img = load(joinpath(testdir, "Picture.png"))
    seg = segment_image(img)
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

    # Test the gui
    rm(tmpfile, force=true)
    btnclick = Condition()
    whichbutton = Ref{Symbol}()
    @async gui(tmpfile, [joinpath(testdir, "Picture.png")]; btnclick, whichbutton, preclick=3)
    sleep(5)
    whichbutton[] = :done
    notify(btnclick)
    wait(btnclick)
    @test isfile(tmpfile)
    @test isfile(splitext(tmpfile)[1] * ".jld2")

    # Test the density map
    count = density_map(splitext(tmpfile)[1] * ".jld2")
    @test extrema(count) == (0, 1)
end
