const std = @import("std");
const Allocator = std.mem.Allocator;
const Console = @import("../Console.zig");
const Client = @import("../Client.zig");
const Config = @import("../Config.zig");

pub fn login(
    allocator: Allocator,
    client: *Client,
    config: *Config,
    console: *Console,
) !void {
    try console.write("Username: ");
    const username = try console.readLine(16);
    defer allocator.free(username);

    try console.write("Password: ");
    const password = try console.readPassword(32);
    defer allocator.free(password);

    const response = try client.login(username, password);
    defer response.destroy(allocator);

    if (response.status != .ok) {
        const err = try response.read();
        defer allocator.free(err);

        try console.writeFmt("Error logging in: {s}\n", .{err});

        return if (response.status == .unauthorized)
            return error.InvalidUsernameOrPassword
        else
            return error.UnexpectedStatusCode;
    }

    const body = try response.into(Client.Auth.Response, allocator);
    defer body.deinit();

    const auth_token = try allocator.alloc(u8, body.value.authToken.len);
    @memcpy(auth_token, body.value.authToken);

    config.updateAuthToken(allocator, auth_token);
}

pub fn register(
    allocator: Allocator,
    client: *Client,
    config: *Config,
    console: *Console,
) !void {
    try console.write("Username: ");
    const username = try console.readLine(16);
    defer allocator.free(username);

    try console.write("Password: ");
    const password = try console.readPassword(32);
    defer allocator.free(password);

    const response = try client.register(username, password);
    defer response.destroy(allocator);

    if (response.status != .ok) {
        const err = try response.read();
        defer allocator.free(err);

        try console.writeFmt("Error logging in: {s}\n", .{err});

        return if (response.status == .conflict)
            return error.UsernameTaken
        else
            return error.UnexpectedStatusCode;
    }

    const body = try response.into(Client.Auth.Response, allocator);
    defer body.deinit();

    const auth_token = try allocator.alloc(u8, body.value.authToken.len);
    @memcpy(auth_token, body.value.authToken);

    config.updateAuthToken(allocator, auth_token);
}
