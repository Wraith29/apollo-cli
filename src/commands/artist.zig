const std = @import("std");
const Allocator = std.mem.Allocator;
const Args = @import("../Args.zig");
const Client = @import("../Client.zig");

pub fn add(allocator: Allocator, args: *Args, client: *Client) !void {
    const artist_name = args.next() orelse return error.MissingRequiredPositionalArg;

    const response = try client.addArtist(artist_name);
    defer response.destroy(allocator);

    if (response.status != .ok) {
        return error.AddArtistFailed;
    }
}
