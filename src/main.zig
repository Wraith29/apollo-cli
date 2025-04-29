const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const process = std.process;

const Allocator = mem.Allocator;
const EnvMap = process.EnvMap;

const Client = @import("Client.zig");

fn loadDotenv(allocator: Allocator, filepath: []const u8) !EnvMap {
    var env_map = try process.getEnvMap(allocator);
    errdefer env_map.deinit();

    var buffer: [2 * 1024]u8 = undefined;
    const data = try fs.cwd().readFile(filepath, &buffer);

    var line_iter = std.mem.splitSequence(u8, data, "\n");

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        const split_idx = mem.indexOf(u8, line, "=") orelse continue;

        const key = line[0..split_idx];
        const value = line[split_idx + 1 .. line.len];

        try env_map.put(key, value);
    }

    return env_map;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var env = try loadDotenv(allocator, ".env");
    defer env.deinit();

    const base_url = env.get("APOLLO_BASE_URL") orelse return error.MissingRequiredEnvVar;

    var client = Client.init(allocator, base_url);
    defer client.deinit();

    const response = try client.login("Wraith", "ActionDog2002!");
    defer response.deinit();

    std.log.info("Got Result: {s}", .{response.value.authToken});
}
