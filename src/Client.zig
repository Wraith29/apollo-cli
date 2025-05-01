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

fn buildUrl(self: *const Self, endpoint: []const u8) ![]const u8 {
    return mem.concat(self.allocator, u8, &.{ self.base_url, endpoint });
}

const Response = struct {
    status: http.Status = undefined,
    body: ArrayList(u8),

    fn init(allocator: Allocator) Response {
        return Response{
            .body = ArrayList(u8).init(allocator),
        };
    }

    fn deinit(self: *Response) void {
        self.body.deinit();
    }

    fn create(allocator: Allocator) !*Response {
        const result = try allocator.create(Response);
        result.* = Response.init(allocator);
        return result;
    }

    pub fn destroy(self: *Response, allocator: Allocator) void {
        self.deinit();
        allocator.destroy(self);
    }

    pub fn into(self: *Response, comptime T: type, allocator: Allocator) !json.Parsed(T) {
        const response_body = try self.body.toOwnedSlice();
        defer allocator.free(response_body);

        return std.json.parseFromSlice(T, allocator, response_body, .{ .allocate = .alloc_always });
    }
};

fn post(
    self: *Self,
    comptime TRequest: type,
    endpoint: []const u8,
    body: TRequest,
) !*Response {
    const payload = try json.stringifyAlloc(self.allocator, body, .{});
    defer self.allocator.free(payload);

    const url = try mem.concat(self.allocator, u8, &.{ self.base_url, endpoint });
    defer self.allocator.free(url);

    const response = try Response.create(self.allocator);
    errdefer response.destroy(self.allocator);

    const fetch_result = try self.client.fetch(.{
        .method = .POST,
        .location = .{ .url = url },
        .payload = payload,
        .headers = .{ .content_type = .{ .override = "application/json" } },
        .response_storage = .{ .dynamic = &response.body },
    });

    response.status = fetch_result.status;

    return response;
}

pub const Auth = struct {
    const Request = struct { username: []const u8, password: []const u8 };
    pub const Response = struct { authToken: []const u8 };

    pub const Error = error{
        UsernameTaken,
        InvalidUsernameOrPassword,
        InvalidStatusCode,
    };
};

pub fn login(self: *Self, username: []const u8, password: []const u8) !*Response {
    return self.post(Auth.Request, "auth/login", .{ .username = username, .password = password });
}

pub fn register(self: *Self, username: []const u8, password: []const u8) !*Response {
    return self.post(Auth.Request, "auth/register", .{ .username = username, .password = password });
}
