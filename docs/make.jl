using CounterMarking
using Documenter

DocMeta.setdocmeta!(CounterMarking, :DocTestSetup, :(using CounterMarking); recursive=true)

makedocs(;
    modules=[CounterMarking],
    authors="Tim Holy <tim.holy@gmail.com> and contributors",
    sitename="CounterMarking.jl",
    format=Documenter.HTML(;
        canonical="https://HolyLab.github.io/CounterMarking.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/HolyLab/CounterMarking.jl",
    devbranch="main",
)
