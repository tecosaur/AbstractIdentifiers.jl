# DigitalIdentifiersBase.jl

A tiny framework for structured and validated identifier types.

## Types

```@docs
AbstractIdentifier
MalformedIdentifier
ChecksumViolation
```

## Interface

```@docs
Base.parse(::Type{<:AbstractIdentifier}, ::String)
Base.tryparse(::Type{<:AbstractIdentifier}, ::String)
Base.print(::IO, ::AbstractIdentifier)
DigitalIdentifiersBase.idcode
DigitalIdentifiersBase.idchecksum
DigitalIdentifiersBase.shortcode
DigitalIdentifiersBase.purl
DigitalIdentifiersBase.purlprefix
```

## Helper functions

```@docs
DigitalIdentifiersBase.@reexport
DigitalIdentifiersBase.parseid
DigitalIdentifiersBase.parsefor
DigitalIdentifiersBase.lchopfolded
```
