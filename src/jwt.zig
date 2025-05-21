const std = @import("std");
const json = std.json;
const base64 = std.base64;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const JwtError = error{
    InvalidToken,
} || Allocator.Error || base64.Error || json.Error || json.ParseError(json.Scanner);

fn decodeToJson(
    comptime T: type,
    decoder: base64.Base64Decoder,
    allocator: Allocator,
    raw: []const u8,
) JwtError!json.Parsed(T) {
    const size = try decoder.calcSizeForSlice(raw);
    const buf = try allocator.alloc(u8, size);
    defer allocator.free(buf);

    try decoder.decode(buf, raw);

    return try json.parseFromSlice(
        T,
        allocator,
        buf,
        .{ .allocate = .alloc_always, .ignore_unknown_fields = true },
    );
}

const Claims = struct { exp: i32 };

pub fn isExpired(
    allocator: Allocator,
    token: []const u8,
) JwtError!bool {
    var iter = std.mem.splitSequence(u8, token, ".");
    const decoder = std.base64.Base64Decoder.init(std.base64.standard_alphabet_chars, null);

    _ = iter.next() orelse return JwtError.InvalidToken;
    const claims_str = iter.next() orelse return JwtError.InvalidToken;

    var claims = try decodeToJson(Claims, decoder, allocator, claims_str);
    defer claims.deinit();

    const now = std.time.timestamp();

    return now > claims.value.exp;
}
