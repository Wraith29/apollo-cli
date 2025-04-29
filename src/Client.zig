const std = @import("std");
const http = std.http;
const json = std.json;
const mem = std.mem;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Self = @This();

allocator: Allocator,
base_url: []const u8,
client: http.Client,

pub fn init(allocator: Allocator, base_url: []const u8) Self {
    return Self{
        .allocator = allocator,
        .base_url = base_url,
        .client = http.Client{ .allocator = allocator },
    };
}

pub fn deinit(self: *Self) void {
    self.client.deinit();
}
fn post(
    self: *Self,
    comptime TRequest: type,
    comptime TResult: type,
    endpoint: []const u8,
    body: TRequest,
) !json.Parsed(TResult) {
    const payload = try json.stringifyAlloc(self.allocator, body, .{});
    defer self.allocator.free(payload);

    const url = try mem.concat(self.allocator, u8, &.{ self.base_url, endpoint });
    defer self.allocator.free(url);

    var response_body = ArrayList(u8).init(self.allocator);

    const response = try self.client.fetch(.{
        .method = .POST,
        .location = .{ .url = url },
        .payload = payload,
        .headers = .{ .content_type = .{ .override = "application/json" } },
        .response_storage = .{ .dynamic = &response_body },
    });

    if (response.status != .ok) {
        std.log.err("status code was not ok {any}", .{response.status});

        return error.InvalidStatusCode;
    }

    const data = try response_body.toOwnedSlice();
    defer self.allocator.free(data);

    return try json.parseFromSlice(TResult, self.allocator, data, .{ .allocate = .alloc_always });
}

const AuthRequest = struct { username: []const u8, password: []const u8 };
const AuthResponse = struct { authToken: []const u8 };

pub fn login(self: *Self, username: []const u8, password: []const u8) !*AuthResponse {
    const response = try self.post(
        AuthRequest,
        AuthResponse,
        "auth/login",
        .{ .username = username, .password = password },
    );
    defer response.deinit();

    const result = try self.allocator.create(AuthResponse);
    @memcpy(result, response.value);

    return result;
}
