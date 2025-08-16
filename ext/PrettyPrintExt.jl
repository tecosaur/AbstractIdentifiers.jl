# SPDX-FileCopyrightText: © 2025 TEC <contact@tecosaur.net>
# SPDX-License-Identifier: MPL-2.0

module PrettyPrintExt

using DigitalIdentifiersBase: AbstractIdentifier, MalformedIdentifier, ChecksumViolation, purl, shortcode, lchopfolded

using StyledStrings: @styled_str as @S_str

function Base.showerror(io::IO, @nospecialize(ex::MalformedIdentifier{T})) where {T}
    print(io, S"Malformed identifier: {bold:$T} identifier {emphasis:$(ex.input)} $(ex.problem)")
end

function Base.showerror(io::IO, @nospecialize(ex::ChecksumViolation{T})) where {T}
    print(io, S"Checksum violation: the correct checksum for {bold:$T} identifier {emphasis:$(ex.id)} \
                is {success:$(ex.expected)} but got {error:$(ex.provided)}")
end

function Base.show(io::IO, ::MIME"text/plain", id::AbstractIdentifier)
    label = String(nameof(typeof(id)))
    lowerlabel = lowercase(label)
    url = purl(id)
    idstr = SubString(shortcode(id))
    _, idstr = if ':' in idstr
        lchopfolded(idstr, lowerlabel * ':')
    else
        lchopfolded(idstr, lowerlabel)
    end
    if endswith(label, "ID")
        idstr = chopprefix(idstr, chopsuffix(label, "ID"))
    end
    if get(io, :typeinfo, Nothing) != typeof(id)
        print(io, S"{bold:$label:}")
    end
    if isnothing(url)
        print(io, S"$idstr")
    else
        print(io, S"{link=$url:$idstr}")
    end
end

end
