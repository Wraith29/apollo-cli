const std = @import("std");
const Allocator = std.mem.Allocator;

const Client = @import("../Client.zig");
const Config = @import("../Config.zig");
const Console = @import("../Console.zig");

pub fn get(allocator: Allocator, client: *Client, config: *Config, console: *Console) !void {
    const response = try client.getRecommendation();
    defer response.destroy(allocator);

    return switch (response.status) {
        .ok => {
            const recommendation = try response.into(struct { albumId: []const u8, albumName: []const u8, artistName: []const u8 }, allocator);
            defer recommendation.deinit();

            try console.writeFmt("Recommended Album: {s} by {s}\n", .{ recommendation.value.albumName, recommendation.value.artistName });

            const rec_id = try allocator.alloc(u8, recommendation.value.albumId.len);
            @memcpy(rec_id, recommendation.value.albumId);

            config.updateLatestRecommendation(allocator, rec_id);
            try config.save(allocator);
        },
        .bad_request => {
            std.log.err("No Albums Found", .{});
        },
        else => return error.RecommendationFailed,
    };
}
