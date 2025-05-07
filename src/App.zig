const std = @import("std");
const Allocator = std.mem.Allocator;

const Args = @import("Args.zig");
const Client = @import("Client.zig");
const artist = @import("commands/artist.zig");
const auth = @import("commands/auth.zig");
const recommendation = @import("commands/recommendation.zig");
const Config = @import("Config.zig");
const Console = @import("Console.zig");

const Self = @This();

allocator: Allocator,
args: Args,
client: Client,
config: Config,
console: Console,

pub fn init(allocator: Allocator) !Self {
    const config = try Config.load(allocator);

    var client = Client.init(allocator, &config);
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
    if (try self.args.matches(1, "login", &.{"l"}))
        return auth.login(self.allocator, &self.client, &self.config, &self.console)
    else if (try self.args.matches(1, "register", &.{"r"}))
        return auth.register(self.allocator, &self.client, &self.config, &self.console)
    else if (try self.args.matches(1, "add", &.{}))
        return artist.add(self.allocator, &self.args, &self.client)
    else if (try self.args.matches(1, "recommend", &.{"rec"}))
        return recommendation.get(self.allocator, &self.client, &self.config, &self.console);
}
