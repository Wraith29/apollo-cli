const std = @import("std");
const Allocator = std.mem.Allocator;
const EnvMap = std.process.EnvMap;

const App = @import("App.zig");
const files = @import("files.zig");

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
