const std = @import("std");
const mem = std.mem;
const process = std.process;
const Allocator = std.mem.Allocator;

const Self = @This();

args: []const [:0]u8,
len: usize,
index: usize,

pub fn init(allocator: Allocator) !Self {
    const args = try process.argsAlloc(allocator);

    return .{ .args = args, .len = args.len, .index = 0 };
}

pub fn deinit(self: *Self, allocator: Allocator) void {
    process.argsFree(allocator, self.args);
}

pub fn skip(self: *Self) void {
    self.index += 1;
}

pub fn next(self: *Self) ?[]const u8 {
    if (self.index >= self.args.len)
        return null;

    defer self.index += 1;
    return self.args[self.index];
}

pub fn at(self: *const Self, pos: usize) ?[]const u8 {
    if (pos >= self.args.len) return null;

    return self.args[pos];
}

pub fn named(self: *const Self, name: []const u8) ?[]const u8 {
    for (self.args) |arg| {
        if (!mem.containsAtLeast(u8, arg, 1, name))
            continue;

        const split_idx = mem.indexOf(u8, arg, "=") orelse continue;

        return arg[split_idx..];
    }

    return null;
}

pub fn matches(self: *Self, position: usize, name: []const u8, aliases: []const []const u8) !bool {
    if (position >= self.args.len)
        return error.NoCommand;

    const cmd = self.args[position];

    if (std.mem.eql(u8, cmd, name))
        return true;

    for (aliases) |alias| {
        if (std.mem.eql(u8, cmd, alias))
            return true;
    }

    return false;
}
