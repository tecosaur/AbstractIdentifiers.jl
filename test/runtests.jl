# SPDX-FileCopyrightText: © 2025 TEC <contact@tecosaur.net>
# SPDX-License-Identifier: MPL-2.0

using Test

using DigitalIdentifiersBase: DigitalIdentifiersBase, AbstractIdentifier, MalformedIdentifier,
    ChecksumViolation, shortcode, purl, idcode, idchecksum, purlprefix,
    parseid, parsefor, lchopfolded

using StyledStrings, JSON, JSON3

struct MyIdentifier <: AbstractIdentifier
    id::UInt16
end

DigitalIdentifiersBase.idcode(myid::MyIdentifier) = myid.id
DigitalIdentifiersBase.idchecksum(myid::MyIdentifier) =
    sum(digits(myid.id) .* (2 .^ (1:ndigits(myid.id)) .- 1)) % 0xf

@testset "Default shortcode" begin
    @test shortcode(MyIdentifier(1234)) == "1234"
end

DigitalIdentifiersBase.shortcode(myid::MyIdentifier) =
    string(myid.id) * string(idchecksum(myid), base=16)

DigitalIdentifiersBase.purlprefix(::Type{MyIdentifier}) = "http://example.com/myid/"

function MyIdentifier(id::Integer, checksum::Integer)
    id > typemax(UInt16) && throw(MalformedIdentifier{MyIdentifier}(id, "ID must be less than $(typemax(UInt16))"))
    myid = MyIdentifier(UInt16(id))
    idchecksum(myid) == checksum || throw(ChecksumViolation{MyIdentifier}(myid.id, idchecksum(myid), checksum))
    myid
end

function DigitalIdentifiersBase.parseid(::Type{MyIdentifier}, id::SubString)
    _, id = lchopfolded(id, "myid:", "http://example.com/myid/")
    str16..., checkchar = id
    i16 = parsefor(MyIdentifier, UInt16, str16)
    i16 isa UInt16 || return MalformedIdentifier{MyIdentifier}(id, "ID must be a valid UInt16")
    check8 = parsefor(MyIdentifier, UInt8, checkchar, base=16)
    check8 isa UInt8 || return MalformedIdentifier{MyIdentifier}(id, "Checksum must be a valid UInt8")
    try
        MyIdentifier(i16, check8)
    catch e
        e
    end
end

myid = MyIdentifier(1234, 0xc)

@testset "Parsing" begin
    @testset "Valid identifiers" begin
        @test parse(MyIdentifier, "1234c") == myid
        @test parse(MyIdentifier, "MyID:1234c") == myid
        @test parse(MyIdentifier, "http://example.com/myid/1234c") == myid
        @test tryparse(MyIdentifier, "1234c") == myid
        @test tryparse(MyIdentifier, "myid:1234c") == myid
        @test tryparse(MyIdentifier, "http://example.com/myid/1234c") == myid
    end
    @testset "Invalid identifiers" begin
        @test tryparse(MyIdentifier, "12345X") === nothing
        @test_throws MalformedIdentifier{MyIdentifier} parse(MyIdentifier, "myid:12345X")
        @test_throws ChecksumViolation{MyIdentifier} parse(MyIdentifier, "myid:12340")
    end
end

@testset "Comparison" begin
    @test parse(MyIdentifier, "1234c") < parse(MyIdentifier, "1235d")
    @test parse(MyIdentifier, "1234c") <= parse(MyIdentifier, "1234c")
    @test parse(MyIdentifier, "1234c") > parse(MyIdentifier, "1233b")
end

struct OtherIdentifierID <: AbstractIdentifier
    id::UInt16
end

DigitalIdentifiersBase.idcode(otherid::OtherIdentifierID) = otherid.id
DigitalIdentifiersBase.shortcode(otherid::OtherIdentifierID) =
    string("OtherIdentifierID:OtherIdentifier", idcode(otherid))

# Test helpers for additional identifier types
struct MultiFieldIdentifier <: AbstractIdentifier
    id::UInt16
    version::UInt8
end
DigitalIdentifiersBase.idcode(x::MultiFieldIdentifier) = x.id
DigitalIdentifiersBase.shortcode(x::MultiFieldIdentifier) = "$(x.id).$(x.version)"

struct NestedIdentifier <: AbstractIdentifier
    inner::MyIdentifier
end
DigitalIdentifiersBase.idcode(ni::NestedIdentifier) = idcode(ni.inner)

@testset "Output Formatting" begin
    @testset "Basic Output" begin
        @test purl(myid) == "http://example.com/myid/1234c"
        @test sprint(print, myid) == "http://example.com/myid/1234c"
        @test sprint(print, OtherIdentifierID(17)) == "17"
        @test sprint(show, myid) == "parse(MyIdentifier, \"1234c\")"
        @test sprint(show, OtherIdentifierID(17)) == "OtherIdentifierID(17)"
        @test sprint(show, MIME("text/plain"), myid) == "MyIdentifier:1234c"
        @test sprint(show, MIME("text/plain"), OtherIdentifierID(17)) == "OtherIdentifierID:17"
    end

    @testset "IO Context Behavior" begin
        print_cases = [
            ((:limit => true,), "MyIdentifier:1234"),
            ((:limit => true, :compact => true), "1234")
        ]
        for (context_pairs, expected) in print_cases
            @test sprint(print, myid; context=IOContext(stdout, context_pairs...)) == expected
        end

        show_cases = [
            ((:limit => true,), "MyIdentifier:1234c"),
            ((:limit => true, :typeinfo => MyIdentifier), "1234c"),
            ((:limit => true, :compact => true, :typeinfo => MyIdentifier), "1234c")
        ]
        for (context_pairs, expected) in show_cases
            @test sprint(show, myid; context=IOContext(stdout, context_pairs...)) == expected
        end
    end

    @testset "Display Format Variants" begin
        multi_id = MultiFieldIdentifier(123, 2)
        @test sprint(show, multi_id) == "parse(MultiFieldIdentifier, \"123.2\")"

        nested_id = NestedIdentifier(myid)
        @test shortcode(nested_id) == "1234"
        @test sprint(show, nested_id) == "parse(NestedIdentifier, \"1234\")"
    end

    @testset "Error Formatting" begin
        for (input, error_type, message_part) in [
            ("1234x", MalformedIdentifier{MyIdentifier}, "Checksum must be a valid UInt8"),
            ("x1234a", MalformedIdentifier{MyIdentifier}, "ID must be a valid UInt16"),
            ("1234a", ChecksumViolation{MyIdentifier}, "is 12 but got 10")
        ]
            try
                parse(MyIdentifier, input)
                @test false  # Should not reach here
            catch e
                @test e isa error_type
                @test occursin(message_part, sprint(showerror, e))
            end
        end
    end
end

struct ChecksumID <: AbstractIdentifier
    value::UInt16
end
DigitalIdentifiersBase.idchecksum(id::ChecksumID) = id.value % 10

struct NoConstructorID <: AbstractIdentifier
    a::String
    b::String
end
DigitalIdentifiersBase.idchecksum(::NoConstructorID) = 42

@testset "Generic Checksum Constructor" begin
    @test ChecksumID(123, 3).value == 123
    @test ChecksumID(0, 0).value == 0
    @test_throws ChecksumViolation ChecksumID(123, 5)
    try
        ChecksumID(123, 7)
        @test false
    catch e
        @test e isa ChecksumViolation{ChecksumID} && e.expected == 3 && e.provided == 7
    end
    @test_throws MethodError OtherIdentifierID(17, 1)     # No idchecksum
    @test_throws MethodError NoConstructorID("a", "b", 1)  # No single constructor
    @test MyIdentifier(1234, 0xc).id == 1234  # Manual constructor still works
end

@testset "JSON" begin
    @test JSON.parse(JSON.json(myid), MyIdentifier) == myid
    @test JSON3.read(JSON3.write(myid), MyIdentifier) == myid
end
