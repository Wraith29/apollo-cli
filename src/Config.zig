const std = @import("std");
const Allocator = std.mem.Allocator;
const File = std.fs.File;

const files = @import("files.zig");

const Self = @This();
const cfg_file_name = "apollo.zon";
const cfg_max_size = 1024;

base_url: []const u8 = "http://localhost:1300/",
auth_token: ?[]const u8 = null,

fn getConfigFile(allocator: Allocator, read_only: bool) !File {
    const cfg_path = try files.getFilePath(allocator, cfg_file_name);
    defer allocator.free(cfg_path);

    return try std.fs.openFileAbsolute(cfg_path, .{ .mode = if (read_only) .read_only else .write_only });
}

pub fn load(allocator: Allocator) !Self {
    var config_file = try getConfigFile(allocator, true);
    defer config_file.close();

    const config_data = try config_file.readToEndAllocOptions(allocator, cfg_max_size, null, @alignOf(u8), 0);
    defer allocator.free(config_data);

    return std.zon.parse.fromSlice(Self, allocator, config_data, null, .{});
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    allocator.free(self.base_url);
    if (self.auth_token) |tkn|
        allocator.free(tkn);
}

pub fn save(self: *Self, allocator: Allocator) !void {
    var config_file = try getConfigFile(allocator, false);
    defer config_file.close();

    try std.zon.stringify.serialize(self, .{}, config_file.writer());
}
