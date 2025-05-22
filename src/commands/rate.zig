const std = @import("std");
const Allocator = std.mem.Allocator;

const Args = @import("../Args.zig");
const Client = @import("../Client.zig");
const Config = @import("../Config.zig");
const Console = @import("../Console.zig");

pub fn latest(
    allocator: Allocator,
    args: *Args,
    client: *Client,
    config: *Config,
) !void {
    if (config.latest_recommendation == null)
        return error.NoLatestRecommendation;

    const raw_rating = args.at(2) orelse return error.MissingArgument;
    const rating = std.fmt.parseInt(u8, raw_rating, 10) catch return error.InvalidRating;

    const response = try client.rateRecommendation(config.latest_recommendation.?, rating);
    defer response.destroy(allocator);

    const body = try response.read();
    defer allocator.free(body);

    if (response.status.class() != .success)
        return error.RatingFailed;
}
