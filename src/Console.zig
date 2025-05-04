const std = @import("std");
const native_os = @import("builtin").os.tag;
const c = @cImport({
    @cInclude("termios.h");
});

const Allocator = std.mem.Allocator;

const Self = @This();

var original_state: c.termios = undefined;

allocator: Allocator,
stdin: std.fs.File,
stdout: std.fs.File,
term: c.termios,

pub fn init(allocator: Allocator) Self {
    const stdin = std.io.getStdIn();

    var term = c.termios{};
    _ = c.tcgetattr(stdin.handle, &term);
    original_state = term;

    return .{
        .allocator = allocator,
        .stdin = stdin,
        .stdout = std.io.getStdOut(),
        .term = term,
    };
}

pub fn write(self: *Self, line: []const u8) !void {
    try self.stdout.writeAll(line);
}

pub fn writeFmt(self: *Self, comptime fmt: []const u8, args: anytype) !void {
    var output = std.ArrayList(u8).init(self.allocator);
    errdefer output.deinit();

    try std.fmt.format(output.writer(), fmt, args);

    const line = try output.toOwnedSlice();
    defer self.allocator.free(line);

    try self.write(line);
}

pub fn readLine(self: *Self, comptime len: comptime_int) ![]const u8 {
    const response = try self.stdin.reader().readUntilDelimiterAlloc(self.allocator, '\n', len);

    return response;
}

pub fn readPassword(self: *Self, comptime len: comptime_int) ![]const u8 {
    try self.hide();
    const password = try self.readLine(len);
    try self.reset();
    try self.write("\n");

    return password;
}

pub fn hide(self: *Self) !void {
    switch (native_os) {
        .windows => try self.hideW(),
        else => try self.hideZ(),
    }
}

fn hideZ(self: *Self) !void {
    self.term.c_lflag &= ~@as(c.tcflag_t, c.ECHO);
    _ = c.tcsetattr(self.stdin.handle, c.TCSANOW, &self.term);
}

fn hideW(self: *Self) !void {
    _ = self;
    return error.NotImplemented;
}

pub fn reset(self: *Self) !void {
    switch (native_os) {
        .windows => try self.resetW(),
        else => try self.resetZ(),
    }
}

fn resetZ(self: *Self) !void {
    _ = c.tcsetattr(self.stdin.handle, c.TCSANOW, &original_state);
}

fn resetW(self: *Self) !void {
    _ = self;
    return error.NotImplemented;
}
