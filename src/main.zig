const std = @import("std");
const Allocator = std.mem.Allocator;
const EnvMap = std.process.EnvMap;

const App = @import("App.zig");
const files = @import("files.zig");

fn loadDotenv(allocator: Allocator, filepath: []const u8) !EnvMap {
    var env_map = try std.process.getEnvMap(allocator);
    errdefer env_map.deinit();

    var buffer: [2 * 1024]u8 = undefined;
    const data = try std.fs.cwd().readFile(filepath, &buffer);

    var line_iter = std.mem.splitSequence(u8, data, "\n");

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        const split_idx = std.mem.indexOf(u8, line, "=") orelse continue;

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

    if (!try files.appDataDirExists(allocator))
        try files.createAppDataDir(allocator);

    var app = try App.init(allocator);
    defer app.deinit();

    app.run() catch |err| switch (err) {
        else => {
            std.log.err("App failed to run: {!}", .{err});
        },
    };
}
