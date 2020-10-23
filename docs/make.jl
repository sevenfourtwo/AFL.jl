using AFL
using Documenter

makedocs(;
    modules=[AFL],
    authors="Joost <sevenfourtwo@protonmail.com> and contributors",
    repo="https://github.com/sevenfourtwo/AFL.jl/blob/{commit}{path}#L{line}",
    sitename="AFL.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://sevenfourtwo.github.io/AFL.jl",
        assets=String[],
    ),
    pages=[
        "index.md",
        "example.md",
        "internals.md",
        "api.md",
    ],
)

deploydocs(;
    repo="github.com/sevenfourtwo/AFL.jl",
)
