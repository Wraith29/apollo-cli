const std = @import("std");
const mem = std.mem;
const process = std.process;
const Allocator = std.mem.Allocator;

const Self = @This();

args: []const [:0]u8,
index: usize,

pub fn init(allocator: Allocator) !Self {
    const args = try process.argsAlloc(allocator);

    return .{ .args = args, .index = 0 };
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

pub fn named(self: *const Self, name: []const u8) ?[]const u8 {
    for (self.args) |arg| {
        if (!mem.containsAtLeast(u8, arg, 1, name))
            continue;

        const split_idx = mem.indexOf(u8, arg, "=") orelse continue;

        return arg[split_idx..];
    }

    return null;
}
