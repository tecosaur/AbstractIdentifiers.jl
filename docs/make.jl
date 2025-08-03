# SPDX-FileCopyrightText: © 2025 TEC <contact@tecosaur.net>
# SPDX-License-Identifier: MPL-2.0

using Documenter
using DigitalIdentifiersBase

Core.eval(DigitalIdentifiersBase,
          quote
"""
    parse(::Type{T<:AbstractIdentifier}, representation::String) -> T

Parse a string `representation` of a `T` identifier.

All unambiguous identifiers should be parseable, for example:
- `abc123`
- `example:abc123`
- `https://example.com/abc123`

If the identifier is not well-formed, a `MalformedIdentifier` exception will be
thrown.  Should the identifier include a checksum, that does not match, a
`ChecksumViolation` exception will be thrown.
"""
Base.parse(::Type{<:AbstractIdentifier}, ::String) = nothing

"""
    tryparse(::Type{T<:AbstractIdentifier}, representation::String) -> Union{T, Nothing}

Attempt to parse a string `representation` of a `T` identifier.

See [`parse`](@ref Base.parse(::Type{<:AbstractIdentifier}, ::String)) for more details.
"""
Base.tryparse(::Type{<:AbstractIdentifier}, ::String) = nothing

"""
    print(io::IO, id::AbstractIdentifier)

Print an identifier `id` to the given `io` stream.

The identifier should be printed in the most "usual" form, often
with more formatting than a minimal representation, but less
than a full permanent URL.
"""
Base.print(::IO, ::AbstractIdentifier) = nothing
            end)

makedocs(;
    modules=[DigitalIdentifiersBase],
    pages=[
        "Index" => "index.md",
    ],
    format=Documenter.HTML(assets=["assets/favicon.ico"]),
    sitename="DigitalIdentifiersBase.jl",
    authors = "tecosaur",
    warnonly = [:missing_docs],
)

deploydocs(repo="github.com/tecosaur/DigitalIdentifiersBase.jl")
