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
    sum(digits(myid.id) .* (2 .^(1:ndigits(myid.id)) .- 1)) % 0xf

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
    try MyIdentifier(i16, check8) catch e; e end
end

myid = MyIdentifier(1234, 0xc)

struct OtherIdentifier <: AbstractIdentifier
    id::UInt16
end

DigitalIdentifiersBase.idcode(otherid::OtherIdentifier) = otherid.id
DigitalIdentifiersBase.shortcode(otherid::OtherIdentifier) =
    string("OtherIdentifier:ID", idcode(otherid))

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

@testset "Formatting" begin
    @test purl(myid) == "http://example.com/myid/1234c"
    @test sprint(print, myid) == "http://example.com/myid/1234c"
    @test sprint(show, myid) == "parse(MyIdentifier, \"1234c\")"
    @test sprint(show, MIME("text/plain"), myid) == "MyIdentifier:1234c"
    try
        parse(MyIdentifier, "1234x")
    catch e
        @test e isa MalformedIdentifier{MyIdentifier}
        error_msg = sprint(showerror, e)
        @test occursin("Checksum must be a valid UInt8", error_msg)
    end
    try
        parse(MyIdentifier, "x1234a")
    catch e
        @test e isa MalformedIdentifier{MyIdentifier}
        error_msg = sprint(showerror, e)
        @test occursin("ID must be a valid UInt16", error_msg)
    end
    try
        parse(MyIdentifier, "1234a")
    catch e
        @test e isa ChecksumViolation{MyIdentifier}
        error_msg = sprint(showerror, e)
        @test occursin("is 12 but got 10", error_msg)
    end
end

@testset "JSON" begin
    @test JSON.parse(JSON.json(myid), MyIdentifier) == myid
    @test JSON3.read(JSON3.write(myid), MyIdentifier) == myid
end
