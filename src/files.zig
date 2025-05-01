const std = @import("std");
const Allocator = std.mem.Allocator;
const Config = @import("Config.zig");

const app_name = "apollo-cli";

pub fn appDataDirExists(allocator: Allocator) !bool {
    const app_data_dir_path = try std.fs.getAppDataDir(allocator, app_name);
    defer allocator.free(app_data_dir_path);

    std.fs.accessAbsolute(app_data_dir_path, .{}) catch return false;

    return true;
}

pub fn createAppDataDir(allocator: Allocator) !void {
    const app_data_dir_path = try std.fs.getAppDataDir(allocator, app_name);
    defer allocator.free(app_data_dir_path);

    try std.fs.makeDirAbsolute(app_data_dir_path);

    var dir = try std.fs.openDirAbsolute(app_data_dir_path, .{});
    defer dir.close();

    // Create the `apollo.zon` file, and save the Default config into it
    const cfg_fp = try getFilePath(allocator, "apollo.zon");
    defer allocator.free(cfg_fp);
    (try dir.createFile(cfg_fp, .{ .read = true })).close();
    var cfg = Config{};

    try cfg.save(allocator);
}

pub fn getFilePath(allocator: Allocator, file_name: []const u8) ![]const u8 {
    const app_data_dir_path = try std.fs.getAppDataDir(allocator, app_name);
    defer allocator.free(app_data_dir_path);

    return try std.mem.concat(allocator, u8, &.{ app_data_dir_path, std.fs.path.sep_str, file_name });
}
