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
        return self.login();
}

// Login sets the AuthToken in the config to the returned auth token, assuming a valid response
fn login(self: *Self) !void {
    try self.console.write("Username: ");
    const username = try self.console.readLine(16);
    defer self.allocator.free(username);

    try self.console.write("Password: ");
    const password = try self.console.readPassword(32);
    defer self.allocator.free(password);

    const response = try self.client.login(username, password);
    defer response.deinit();

    const auth_token = try self.allocator.alloc(u8, response.value.authToken.len);
    @memcpy(auth_token, response.value.authToken);

    if (self.config.auth_token) |old_token|
        self.allocator.free(old_token);

    self.config.auth_token = auth_token;
}
