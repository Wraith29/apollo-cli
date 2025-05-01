const std = @import("std");
const Allocator = std.mem.Allocator;

const Args = @import("Args.zig");
const Client = @import("Client.zig");
const Config = @import("Config.zig");
const Console = @import("Console.zig");

const Self = @This();

const Error = error{
    NoCommand,
};

allocator: Allocator,
args: Args,
client: Client,
config: Config,
console: Console,

pub fn init(allocator: Allocator) !Self {
    const config = try Config.load(allocator);

    var client = Client.init(allocator, config.base_url);
    errdefer client.deinit();

    const console = Console.init(allocator);

    var args = try Args.init(allocator);
    // Ignore the exe name
    args.skip();

    return Self{
        .allocator = allocator,
        .args = args,
        .client = client,
        .config = config,
        .console = console,
    };
}

pub fn deinit(self: *Self) void {
    self.config.save(self.allocator) catch |err|
        std.log.err("Failed to save config: {!}", .{err});

    self.config.deinit(self.allocator);
    self.client.deinit();
    self.args.deinit(self.allocator);
}

pub fn run(self: *Self) !void {
    const cmd = self.args.next() orelse return Error.NoCommand;

    if (std.mem.eql(u8, cmd, "login"))
        return self.authenticate(true)
    else if (std.mem.eql(u8, cmd, "register"))
        return self.authenticate(false);
}

fn authenticate(self: *Self, is_login: bool) !void {
    try self.console.write("Username: ");
    const username = try self.console.readLine(16);
    defer self.allocator.free(username);

    try self.console.write("Password: ");
    const password = try self.console.readPassword(32);
    defer self.allocator.free(password);

    const response = if (is_login)
        try self.client.login(username, password)
    else
        try self.client.register(username, password);
    defer response.destroy(self.allocator);

    if (response.status != .ok) {
        if (!is_login and response.status == .conflict)
            return error.UsernameTaken
        else if (is_login and response.status == .unauthorized)
            return error.InvalidUsernameOrPassword
        else
            return error.InvalidStatusCode;
    }

    const body = try response.into(Client.Auth.Response, self.allocator);
    defer body.deinit();

    const auth_token = try self.allocator.alloc(u8, body.value.authToken.len);
    @memcpy(auth_token, body.value.authToken);

    if (self.config.auth_token) |old_token|
        self.allocator.free(old_token);

    self.config.auth_token = auth_token;
}
