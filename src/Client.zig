const std = @import("std");
const http = std.http;
const json = std.json;
const mem = std.mem;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Config = @import("Config.zig");
const jwt = @import("jwt.zig");

const Self = @This();

allocator: Allocator,
base_url: []const u8,
auth_token: ?[]const u8 = null,
client: http.Client,

pub fn init(allocator: Allocator, config: *const Config) Self {
    return Self{
        .allocator = allocator,
        .base_url = config.base_url,
        .auth_token = config.auth_token,
        .client = http.Client{ .allocator = allocator },
    };
}

pub fn deinit(self: *Self) void {
    self.client.deinit();
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

    pub fn read(self: *Response) ![]const u8 {
        return self.body.toOwnedSlice();
    }
};

fn requestWithBody(
    self: *Self,
    comptime TRequest: type,
    method: http.Method,
    endpoint: []const u8,
    body: TRequest,
    headers: []const http.Header,
) !*Response {
    const payload = try json.stringifyAlloc(self.allocator, body, .{});
    defer self.allocator.free(payload);

    const url = try mem.concat(self.allocator, u8, &.{ self.base_url, endpoint });
    defer self.allocator.free(url);

    const response = try Response.create(self.allocator);
    errdefer response.destroy(self.allocator);

    const fetch_result = try self.client.fetch(.{
        .method = method,
        .location = .{ .url = url },
        .payload = payload,
        .headers = .{ .content_type = .{ .override = "application/json" } },
        .extra_headers = headers,
        .response_storage = .{ .dynamic = &response.body },
    });

    response.status = fetch_result.status;

    return response;
}

fn post(
    self: *Self,
    comptime TRequest: type,
    endpoint: []const u8,
    body: TRequest,
    headers: []const http.Header,
) !*Response {
    return self.requestWithBody(TRequest, .POST, endpoint, body, headers);
}

fn put(
    self: *Self,
    comptime TRequest: type,
    endpoint: []const u8,
    body: TRequest,
    headers: []const http.Header,
) !*Response {
    return self.requestWithBody(TRequest, .PUT, endpoint, body, headers);
}

fn get(
    self: *Self,
    endpoint: []const u8,
    headers: []const http.Header,
) !*Response {
    const url = try mem.concat(self.allocator, u8, &.{ self.base_url, endpoint });
    defer self.allocator.free(url);

    const response = try Response.create(self.allocator);
    errdefer response.destroy(self.allocator);

    const fetch_result = try self.client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .extra_headers = headers,
        .response_storage = .{ .dynamic = &response.body },
    });

    response.status = fetch_result.status;

    return response;
}

const Error = error{
    UsernameTaken,
    InvalidUsernameOrPassword,
    InvalidStatusCode,
};

pub const Auth = struct {
    const Request = struct { username: []const u8, password: []const u8 };
    pub const Response = struct { authToken: []const u8 };
};

pub fn login(self: *Self, username: []const u8, password: []const u8) !*Response {
    return self.post(Auth.Request, "auth/login", .{ .username = username, .password = password }, &.{});
}

pub fn register(self: *Self, username: []const u8, password: []const u8) !*Response {
    return self.post(Auth.Request, "auth/register", .{ .username = username, .password = password }, &.{});
}

const AuthError = error{ TokenNotFound, TokenExpired };

fn checkToken(self: *const Self) !void {
    if (self.auth_token == null)
        return AuthError.TokenNotFound;

    if (try jwt.isExpired(self.allocator, self.auth_token.?))
        return AuthError.TokenExpired;
}

pub fn addArtist(self: *Self, artist_name: []const u8) !*Response {
    try self.checkToken();

    return self.post(
        struct { artistName: []const u8 },
        "artist",
        .{ .artistName = artist_name },
        &.{
            .{ .name = "Authorization", .value = self.auth_token.? },
        },
    );
}

pub fn getRecommendation(self: *Self) !*Response {
    try self.checkToken();

    return self.get("album/recommendation", &.{
        .{ .name = "Authorization", .value = self.auth_token.? },
    });
}

pub fn rateRecommendation(self: *Self, album_id: []const u8, rating: u8) !*Response {
    try self.checkToken();

    return self.put(
        struct { albumId: []const u8, rating: u8 },
        "album/rating",
        .{ .albumId = album_id, .rating = rating },
        &.{.{ .name = "Authorization", .value = self.auth_token.? }},
    );
}

pub fn listArtists(self: *Self) !*Response {
    try self.checkToken();

    return self.get(
        "artists",
        &.{.{ .name = "Authorization", .value = self.auth_token.? }},
    );
}

pub fn listAlbums(self: *Self) !*Response {
    try self.checkToken();

    return self.get(
        "albums",
        &.{.{ .name = "Authorization", .value = self.auth_token.? }},
    );
}

pub fn listRecommendations(self: *Self) !*Response {
    try self.checkToken();

    return self.get(
        "recommendations",
        &.{.{ .name = "Authorization", .value = self.auth_token.? }},
    );
}
