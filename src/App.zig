const std = @import("std");
const Allocator = std.mem.Allocator;

const Args = @import("Args.zig");
const Client = @import("Client.zig");
const artist = @import("commands/artist.zig");
const auth = @import("commands/auth.zig");
const recommendation = @import("commands/recommendation.zig");
const rate = @import("commands/rate.zig");
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
    if (self.args.len == 1) {
        return self.help();
    }

    if (try self.args.matches(1, "login", &.{}))
        return auth.login(self.allocator, &self.client, &self.config, &self.console)
    else if (try self.args.matches(1, "register", &.{}))
        return auth.register(self.allocator, &self.client, &self.config, &self.console)
    else if (try self.args.matches(1, "add", &.{}))
        return artist.add(self.allocator, &self.args, &self.client)
    else if (try self.args.matches(1, "recommend", &.{"rec"}))
        return recommendation.get(self.allocator, &self.client, &self.config, &self.console)
    else if (try self.args.matches(1, "rate", &.{}))
        return rate.latest(self.allocator, &self.args, &self.client, &self.config, &self.console);
}

fn help(self: *Self) !void {
    return self.console.write(
        \\Apollo
        \\------
        \\
        \\Commands:
        \\  login
        \\    Sign in to an existing Apollo account.
        \\    Prompts for your Username & Password
        \\
        \\  register
        \\    Create a new Apollo account.
        \\    Prompts for your Username & Password
        \\
        \\  add [artist]
        \\    Adds the given artist to your personal library
        \\
        \\  recommend (rec) [-a --all] [...genres]
        \\    Recommend an album from your library to listen to
        \\    [-a --all] Include albums you've already been recommended
        \\    [...genres] Filter down to albums that have the given tags (max 3)
        \\
    );
}
