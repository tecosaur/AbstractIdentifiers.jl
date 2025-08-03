# SPDX-FileCopyrightText: © 2025 TEC <contact@tecosaur.net>
# SPDX-License-Identifier: MPL-2.0

module DigitalIdentifiersBase

export AbstractIdentifier, MalformedIdentifier, ChecksumViolation, shortcode, purl

@static if VERSION >= v"1.11"
    eval(Expr(:public, :idcode, :idchecksum, :purlprefix, :parseid, :parsefor, :lchopfolded, Symbol("@reexport")))
end

"""
    DigitalIdentifiersBase.@reexport

Export all of the user-facing components of the `DigitalIdentifiersBase` module,
namely:
- `AbstractIdentifier`
- `MalformedIdentifier`
- `ChecksumViolation`
- `shortcode`
- `purl`
"""
macro reexport()
    quote
        using DigitalIdentifiersBase: AbstractIdentifier, MalformedIdentifier, ChecksumViolation, shortcode, purl
        export AbstractIdentifier, MalformedIdentifier, ChecksumViolation, shortcode, purl
    end
end

"""
    AbstractIdentifier

An abstract type representing a standard identifier.

Abstract identifiers are unique identifiers referring to resources used in
academic and scholarly contexts.  This type is used to
represent a common interface for working with these identifiers.

It is expected that all identifiers have a plain text canonical form, and
optionally a PURL (Persistent Uniform Resource Locator) that can be used to link
to the resource. These may be one and the same.

# Extended help

**Interface and guidelines**

## Mandatory components

Your identifier, named `ID` for example, must be able to be constructed from its
canonical form as well as the plain form (these may be the same).

```julia
parseid(ID, "canonical string form or purl") -> ID or Exception
parseid(ID, "minimal plain form") -> ID or Exception
shortcode(::ID) -> String
```

The `parseid` function is used in generic `parse` and `tryparse` implementations.
You can either implement `parseid` or define both `parse` and `tryparse` methods.

Invariants:
- `ID(shortcode(x::ID)) == x`
- `x::ID == y::ID` *iff* `shortcode(x) == shortcode(y)`

If the constructor is passed a string that doesn't match the expected format, is
is reasonable to throw a [`MalformedIdentifier`](@ref) error.

When there is a checksum component to the identifier, it is usual for an inner
constructor to be defined that verifies the checksum matches or throw a
[`ChecksumViolation`](@ref) error. This makes invalid identifiers
unconstructable.

## Abstract components

Most identifiers can be represented in a numerical form, possibly with a
checksum value. Should that be the case, it is recommended that you define the
`idcode` and `idchecksum` accessors.

```
idcode(::ID) -> Integer
idchecksum(::ID) -> Integer
```

When `idcode` is defined, the generic `shortcode` function will use it to
construct the plain string representation of the identifier.

Invariants:
- `idcode(x::ID) == idcode(y::ID) && idchecksum(x) == idchecksum(y)` *iff* `x == y`

## Optional components

When a standard persistent URL exists for the resource, you should define either
`purlprefix` when the URL is of the form `\$prefix\$(shortcode(x::ID))` or
`purl(x::ID)` when the URL scheme is more complicated.

```
purlprefix(::Type{ID}) -> String
purl(::Type{ID}) -> String
```

Invariants:
- `parse(ID, purl(x::ID)) == x`
- `purl(x::ID) == purl(y::ID)` *iff* `x == y`

## Example implementation

Let's say we want to implement a simple numeric code called "MyId", which uses
the format `MyId:<number>` where `<number>` is between 0 and 65535. Suppose that
these IDs also have a permanent URL of the form
`https://example.com/myid/<number>`.

We want to implement support for:
- parsing the forms `<number>`, `MyId:<number>` (case insensitive), and `https://example.com/myid/<number>`
- providing the `purl` of a MyId
- displaying the MyId appropriately

This can be achieved with the following implementation:

```julia
struct MyIdentifier <: AbstractIdentifier
    id::UInt16
end

DigitalIdentifiersBase.idcode(simpleid::MyIdentifier) = simpleid.id
DigitalIdentifiersBase.purlprefix(::Type{MyIdentifier}) = "http://example.com/myid/"

function DigitalIdentifiersBase.parseid(::Type{MyIdentifier}, id::SubString)
    _, id = lchopfolded(id, "myid:", "http://example.com/myid/")
    i16 = parsefor(MyIdentifier, UInt16, id)
    i16 isa UInt16 || return MalformedIdentifier{MyIdentifier}("ID must be a valid UInt16")
    MyIdentifier(i16)
end
```

Support for `parse` and `tryparse` is made easier by implementing `parseid`

To add checksum support, we will:
1. Implement `idchecksum` for calculating/retrieving the checksum
2. Implement `shortcode` to include the checksum at the end
3. Add a `MyIdentifier` constructor that takes a checksum argument
4. Modify `parseid` to pull out the checksum

```julia
DigitalIdentifiersBase.idchecksum(myid::MyIdentifier) =
    sum(digits(myid.id) .* (2 .^(1:ndigits(myid.id)) .- 1)) % 0xf

DigitalIdentifiersBase.shortcode(myid::MyIdentifier) =
    string(myid.id) * string(idchecksum(myid), base=16)

function MyIdentifier(id::Integer, checksum::Integer)
    id > typemax(UInt16) && throw(MalformedIdentifier{MyIdentifier}("ID must be less than $(typemax(UInt16))"))
    myid = MyIdentifier(UInt16(id))
    idchecksum(myid) == checksum || throw(ChecksumViolation{MyIdentifier}(myid.id, idchecksum(myid), checksum))
    myid
end

function DigitalIdentifiersBase.parseid(::Type{MyIdentifier}, id::SubString)
    _, id = lchopfolded(id, "myid:", "http://example.com/myid/")
    str16..., checkchar = id
    i16 = parsefor(MyIdentifier, UInt16, str16)
    i16 isa UInt16 || return MalformedIdentifier{MyIdentifier}("ID must be a valid UInt16")
    check8 = parsefor(MyIdentifier, UInt8, checkchar, base=16)
    check8 isa UInt8 || return MalformedIdentifier{MyIdentifier}("Checksum must be a valid UInt8")
    try MyIdentifier(i16, check8) catch e; e end
end
```
"""
abstract type AbstractIdentifier end

"""
    parseid(::Type{T}, input::SubString) -> Union{T, MalformedIdentifier{T}, ChecksumViolation{T}}

Attempt to parse the `input` string as an identifier of type `T`.

This is used by the generic `parse` and `tryparse` functions to interpret a string as a `T`, and
should be implemented by  `AbstractIdentifier` subtypes.
"""
function parseid end

function Base.parse(::Type{T}, input::AbstractString) where {T <: AbstractIdentifier}
    id = parseid(T, SubString(input))
    id isa T || throw(id)
    id
end

function Base.tryparse(::Type{T}, input::AbstractString) where {T <: AbstractIdentifier}
    id = parseid(T, SubString(input))
    if id isa T id end
end

"""
    MalformedIdentifier{T<:AbstractIdentifier}(input, problem::String) -> MalformedIdentifier{T}

The provided `input` is not a recognised form of a `T` identifier,
due to the specified `problem`.
"""
struct MalformedIdentifier{T <: AbstractIdentifier, I} <: Exception
    input::I
    problem::String
end

MalformedIdentifier{T}(input::I, problem::String) where {T, I} =
    MalformedIdentifier{T, I}(input, problem)

"""
    ChecksumViolation{T<:AbstractIdentifier}(id, expected, provided) -> ChecksumViolation{T}

The `provided` checksum for the `T` identifier `id` is incorrect; the correct
checksum is `expected`.
"""
struct ChecksumViolation{T <: AbstractIdentifier, I} <: Exception
    id::I
    expected::Integer
    provided::Integer
end

ChecksumViolation{T}(id::I, expected::Integer, provided::Integer) where {T, I} =
    ChecksumViolation{T, I}(id, expected, provided)

"""
    idcode(id::AbstractIdentifier) -> Union{Integer, Nothing}

If applicable, return the base identifier of an `AbstractIdentifier`.
"""
function idcode(::AbstractIdentifier) end

"""
    idchecksum(id::AbstractIdentifier) -> Union{Integer, Nothing}

If applicable, return the check digit of an `AbstractIdentifier`.
"""
function idchecksum(::AbstractIdentifier) end

"""
    shortcode(id::AbstractIdentifier) -> String

Return a plain string representation of an `AbstractIdentifier`.

This should be the minimal complete representation of the identifier,
with no additional formatting.

The canonical form for the identifier should contain the plain identifier,
but may include additional information such as a standard prefix and/or suffix.
"""
shortcode(id::AbstractIdentifier) = string(idcode(id))

"""
    purlprefix(::Type{<:AbstractIdentifier}) -> Union{String, Nothing}

Return the standard prefix of a PURL for an `AbstractIdentifier`, if applicable.

If defined, this implies that a PURL can be constructed by appending the `shortcode`
representation of the identifier to this prefix. As such, you should take care to
include any necessary trailing slashes or other separators in this prefix.
"""
function purlprefix(::Type{T}) where {T <: AbstractIdentifier} end

purlprefix(::T) where {T <: AbstractIdentifier} = purlprefix(T)

"""
    purl(id::AbstractIdentifier) -> Union{String, Nothing}

If applicable, return the PURL of an `AbstractIdentifier`.

PURLs are Persistent Uniform Resource Locators that provide a permanent link to
a resource.
"""
function purl(id::AbstractIdentifier)
    prefix = purlprefix(id)
    if !isnothing(prefix)
        prefix * shortcode(id)
    end
end

function Base.print(io::IO, id::AbstractIdentifier)
    print(io, something(purl(id), shortcode(id)))
end

function Base.show(io::IO, id::AbstractIdentifier)
    show(io, parse)
    show(io, (typeof(id), shortcode(id)))
end

function Base.isless(a::T, b::T) where {T <: AbstractIdentifier}
    ca = idcode(a)
    cb = idcode(b)
    (isnothing(ca) || isnothing(cb)) && return isless(shortcode(a), shortcode(b))
    ca < cb
end


# Utilities

"""
    parsefor(::Type{T<:AbstractIdentifier}, ::Type{I<:Integer}, num::Union{<:AbstractString, <:AbstractChar})

Attempt to parse the `num` string as an integer of type `I`, returning it if successful.

If the string cannot be parsed as an integer, a `MalformedIdentifier{T}` exception is returned.
"""
function parsefor(::Type{T}, ::Type{I}, num::Union{<:AbstractString, <:AbstractChar}; base::Integer = 10) where {T <: AbstractIdentifier, I <: Integer}
    int = if num isa Char
        try parse(I, num; base) catch end # See: <https://github.com/JuliaLang/julia/issues/45640>
    else
        tryparse(I, num; base)
    end
    if isnothing(int)
        (@noinline function(iT, inum)
             nonint = if inum isa AbstractChar inum else filter(c -> c ∉ '0':'9', inum) end
             MalformedIdentifier{T}(inum, "includes invalid base 10 digit$(ifelse(length(nonint)==1, "", "s")) '$(nonint)'")
         end)(T, num)
    else
        int
    end
end

"""
    chopprefixfolded(s::SubString, prefix::AbstractString) -> Tuple{Bool, SubString}

Remove an ASCII `prefix` from the start of `s`, ignoring case.

The `prefix` argument must be lowercase.
"""
function chopprefixfolded(s::SubString, prefix::AbstractString)
    k = firstindex(s)
    i, j = iterate(s), iterate(prefix)
    while true
        isnothing(j) && isnothing(i) && return true, SubString(s, 1, 0)
        isnothing(j) && return true, @inbounds SubString(s, k)
        isnothing(i) && return false, s
        ui, uj = UInt32(first(i)), UInt32(first(j))
        if ui ∈ 0x41:0x5a
            ui |= 0x20
        end
        ui == uj || return false, s
        k = last(i)
        i, j = iterate(s, k), iterate(prefix, last(j))
    end
end

"""
    lchopfolded(s::SubString, prefixes::AbstractString...) -> Tuple{Bool, SubString}

Remove any of the specified `prefixes` from the start of `s`, ignoring case.

This function will return `true` if any of the prefixes were successfully removed,
and `false` otherwise. The remaining string is returned as a `SubString`.

The `prefixes` arguments must all be lowercase.
"""
function lchopfolded(s::SubString, prefixes::String...)
    chopped = false
    for prefix in prefixes
        did, s = chopprefixfolded(s, prefix)
        chopped |= did
    end
    chopped, s
end

end
