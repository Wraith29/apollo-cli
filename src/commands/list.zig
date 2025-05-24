const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Client = @import("../Client.zig");
const Console = @import("../Console.zig");

const TableElement = struct {
    const Corners = struct {
        const BtmLeft = "└";
        const BtmRight = "┘";
        const TopLeft = "┌";
        const TopRight = "┐";
    };

    const Line = struct {
        const Horizonal = "─";
        const Vertical = "│";
    };

    const Junction = struct {
        const FourWay = "┼";
        const HorizontalDown = "┬";
        const HorizontalUp = "┴";
        const VerticalLeft = "┤";
        const VerticalRight = "├";
    };
};

fn isIgnored(field: []const u8, ignored_fields: []const []const u8) bool {
    for (ignored_fields) |ignore|
        if (std.mem.eql(u8, field, ignore))
            return true;

    return false;
}

fn getMaxLength(allocator: Allocator, comptime T: type, comptime field_name: []const u8, values: []T) !usize {
    var result: usize = field_name.len;

    for (values) |value| {
        const field = @field(value, field_name);

        switch (@typeInfo(@TypeOf(field))) {
            .pointer => |ptr| {
                if (ptr.size != .slice)
                    @compileError("invalid type " ++ @typeName(ptr) ++ " expected []const u8 or int");

                if (!@hasField(@TypeOf(field), "len"))
                    @compileError("invalid type " ++ @typeName(ptr) ++ " expected []const u8 or int");

                if (field.len > result)
                    result = field.len;
            },
            .int => {
                const res = try std.fmt.allocPrint(allocator, "{d}", .{field});
                defer allocator.free(res);

                if (res.len > result)
                    result = res.len;
            },
            else => |typ| {
                @compileError("invalid type " ++ @typeName(typ) ++ " expected []const u8 or int");
            },
        }
    }

    return result + 2;
}

fn getStringRepr(
    allocator: Allocator,
    comptime T: type,
    comptime field_name: []const u8,
    value: T,
) ![]const u8 {
    return switch (@typeInfo(@FieldType(T, field_name))) {
        .pointer => |ptr| {
            if (ptr.size != .slice)
                @compileError("invalid type " ++ @typeName(T) ++ " expected []const u8 or int");

            const str_val = @field(value, field_name);

            const buf = try allocator.alloc(u8, str_val.len);
            @memcpy(buf, str_val);

            return buf;
        },
        .int => {
            const res = try std.fmt.allocPrint(allocator, "{d}", .{@field(value, field_name)});

            return res;
        },
        else => {
            @compileError("invalid type " ++ @typeName(T) ++ " expected []const u8 or int");
        },
    };
}

fn getColumnNames(
    comptime T: type,
    comptime ignored_fields: []const []const u8,
) [std.meta.fieldNames(T).len - ignored_fields.len][]const u8 {
    const all_fields = std.meta.fieldNames(T);
    var headers = [_][]const u8{undefined} ** (all_fields.len - ignored_fields.len);
    var index: usize = 0;

    inline for (all_fields) |field| {
        if (isIgnored(field, ignored_fields))
            continue;

        headers[index] = field;
        index += 1;
    }

    return headers;
}

const Column = struct {
    header: []const u8,
    max_len: usize,

    fn init(comptime header: []const u8, max_len: usize) Column {
        return Column{
            .header = header,
            .max_len = max_len,
        };
    }
};

pub inline fn baseName(comptime T: type) []const u8 {
    const name = @typeName(T);
    const last_idx = std.mem.lastIndexOf(u8, name, ".") orelse @compileError("invalid type name");

    return name[last_idx + 1 ..];
}

fn tabulate(
    comptime T: type,
    allocator: Allocator,
    values: []T,
    comptime ignored_fields: []const []const u8,
) ![]const u8 {
    const table_name = comptime baseName(T) ++ "s";

    const headers = comptime getColumnNames(T, ignored_fields);
    var columns = try allocator.alloc(Column, headers.len);
    defer allocator.free(columns);

    var line_length: usize = headers.len + 1;
    inline for (headers, 0..) |hdr, idx| {
        const max_len = try getMaxLength(allocator, T, hdr, values);
        columns[idx] = Column.init(hdr, max_len);

        line_length += max_len;
    }

    var table = ArrayList(u8).init(allocator);
    var writer = table.writer();

    _ = try writer.write(TableElement.Corners.TopLeft);
    _ = try writer.writeBytesNTimes(TableElement.Line.Horizonal, line_length - 2);
    _ = try writer.write(TableElement.Corners.TopRight);
    _ = try writer.write("\n");

    const side_buffer: usize = @divFloor(line_length - 2 - table_name.len, 2);
    const extra_buffer_after = side_buffer * 2 + table_name.len + 2 != line_length;

    _ = try writer.write(TableElement.Line.Vertical);
    _ = try writer.writeByteNTimes(' ', side_buffer);
    _ = try writer.write(table_name);
    _ = try writer.writeByteNTimes(' ', if (extra_buffer_after) side_buffer + 1 else side_buffer);
    _ = try writer.write(TableElement.Line.Vertical);
    _ = try writer.write("\n");

    _ = try writer.write(TableElement.Junction.VerticalRight);
    for (columns, 0..) |col, idx| {
        _ = try writer.writeBytesNTimes(TableElement.Line.Horizonal, col.max_len);
        if (idx < columns.len - 1)
            _ = try writer.write(TableElement.Junction.HorizontalDown);
    }
    _ = try writer.write(TableElement.Junction.VerticalLeft);
    _ = try writer.write("\n");

    _ = try writer.write(TableElement.Line.Vertical);
    for (columns) |col| {
        _ = try writer.write(" ");
        _ = try writer.write(col.header);
        _ = try writer.writeByteNTimes(' ', col.max_len - col.header.len - 2);
        _ = try writer.write(" ");
        _ = try writer.write(TableElement.Line.Vertical);
    }
    _ = try writer.write("\n");
    _ = try writer.write(TableElement.Junction.VerticalRight);

    for (columns, 0..) |col, idx| {
        _ = try writer.writeBytesNTimes(TableElement.Line.Horizonal, col.max_len);
        if (idx < columns.len - 1)
            _ = try writer.write(TableElement.Junction.FourWay)
        else
            _ = try writer.write(TableElement.Junction.VerticalLeft);
    }
    _ = try writer.write("\n");

    for (values) |value| {
        _ = try writer.write(TableElement.Line.Vertical);

        inline for (headers, 0..) |hdr, idx| {
            const col = columns[idx];
            const col_value = try getStringRepr(allocator, T, hdr, value);
            defer allocator.free(col_value);

            _ = try writer.write(" ");
            _ = try writer.write(col_value);
            _ = try writer.writeByteNTimes(' ', col.max_len - col_value.len - 2);
            _ = try writer.write(" ");
            _ = try writer.write(TableElement.Line.Vertical);
        }
        _ = try writer.write("\n");
    }
    _ = try writer.write(TableElement.Corners.BtmLeft);

    for (columns, 0..) |col, idx| {
        _ = try writer.writeBytesNTimes(TableElement.Line.Horizonal, col.max_len);
        if (idx < columns.len - 1)
            _ = try writer.write(TableElement.Junction.HorizontalUp);
    }
    _ = try writer.write(TableElement.Corners.BtmRight);

    return table.toOwnedSlice();
}

const DateTime = struct {
    year: u16,
    month: u8,
    date: u8,
    hour: u8,
    min: u8,
    sec: u8,

    fn parse(raw: []const u8) !DateTime {
        var sections = std.mem.tokenizeSequence(u8, raw, "T");
        const ymd_str = sections.next() orelse return error.InvalidDateTime;
        const time_str = sections.next() orelse return error.InvalidDateTime;

        var ymd = std.mem.tokenizeSequence(u8, ymd_str, "-");
        const year = try std.fmt.parseInt(u16, ymd.next() orelse return error.InvalidDateTime, 10);
        const month = try std.fmt.parseInt(u8, ymd.next() orelse return error.InvalidDateTime, 10);
        const date = try std.fmt.parseInt(u8, ymd.next() orelse return error.InvalidDateTime, 10);

        var hms = std.mem.tokenizeSequence(u8, time_str, ":");
        const hour = try std.fmt.parseInt(u8, hms.next() orelse return error.InvalidDateTime, 10);
        const mins = try std.fmt.parseInt(u8, hms.next() orelse return error.InvalidDateTime, 10);

        var secs = std.mem.tokenizeSequence(u8, hms.next() orelse return error.InvalidDateTime, ".");
        const seconds = try std.fmt.parseInt(u8, secs.next() orelse return error.InvalidDateTime, 10);

        return DateTime{
            .year = year,
            .month = month,
            .date = date,
            .hour = hour,
            .min = mins,
            .sec = seconds,
        };
    }

    fn greaterThan(self: *const DateTime, other: *const DateTime) bool {
        if (self.year > other.year)
            return true
        else if (self.year < other.year)
            return false;

        if (self.month > other.month)
            return true
        else if (self.month < other.month)
            return false;

        if (self.date > other.date)
            return true
        else if (self.date < other.date)
            return false;

        if (self.hour > other.hour)
            return true
        else if (self.hour < other.hour)
            return false;

        if (self.min > other.min)
            return true
        else if (self.min < other.min)
            return false;

        if (self.sec > other.sec)
            return true
        else if (self.sec < other.sec)
            return false;

        return true;
    }
};

// While this struct may violate naming conventions for struct fields
// I think it's nicer to have a table with PascalCase headers
// And it's easier to make the field names be PascalCase rather than adding more comptime reflection stuff
// to evaluate a snake_case name into PascalCase.
// Maybe something I'll change in the future, but let's be real. I won't.
const Artist = struct {
    ArtistName: []const u8,
    Rating: u8,
    UpdatedAt: []const u8,

    updated_at: ?DateTime = null,

    fn setUpdatedAt(self: *Artist) !void {
        self.updated_at = try DateTime.parse(self.UpdatedAt);
    }

    fn lessThan(_: void, self: Artist, other: Artist) bool {
        return !self.updated_at.?.greaterThan(&other.updated_at.?);
    }
};

pub fn artists(allocator: Allocator, client: *Client, console: *Console) !void {
    const response = try client.listArtists();
    defer response.destroy(allocator);

    const all_artists = try response.into([]Artist, allocator);
    defer all_artists.deinit();

    for (all_artists.value) |*artist| {
        try artist.setUpdatedAt();
    }

    std.mem.sort(Artist, all_artists.value, {}, Artist.lessThan);
    std.mem.reverse(Artist, all_artists.value);

    const table = try tabulate(
        Artist,
        allocator,
        all_artists.value,
        &.{"updated_at"},
    );
    defer allocator.free(table);

    try console.write(table);
    try console.write("\n");
}

const Album = struct {
    AlbumName: []const u8,
    ArtistName: []const u8,
    Rating: u8,
    UpdatedAt: []const u8,

    updated_at: ?DateTime = null,

    fn setUpdatedAt(self: *Album) !void {
        self.updated_at = try DateTime.parse(self.UpdatedAt);
    }

    fn lessThan(_: void, self: Album, other: Album) bool {
        return !self.updated_at.?.greaterThan(&other.updated_at.?);
    }
};

pub fn albums(allocator: Allocator, client: *Client, console: *Console) !void {
    const response = try client.listAlbums();
    defer response.destroy(allocator);

    const all_albums = try response.into([]Album, allocator);
    defer all_albums.deinit();

    for (all_albums.value) |*album| {
        try album.setUpdatedAt();
    }

    std.mem.sort(Album, all_albums.value, {}, Album.lessThan);
    std.mem.reverse(Album, all_albums.value);

    const table = try tabulate(
        Album,
        allocator,
        all_albums.value,
        &.{"updated_at"},
    );
    defer allocator.free(table);

    try console.write(table);
    try console.write("\n");
}

const Recommendation = struct {
    AlbumName: []const u8,
    CreatedAt: []const u8,

    created_at: ?DateTime = null,

    fn setCreatedAt(self: *Recommendation) !void {
        self.created_at = try DateTime.parse(self.CreatedAt);
    }

    fn lessThan(_: void, self: Recommendation, other: Recommendation) bool {
        return !self.created_at.?.greaterThan(&other.created_at.?);
    }
};

pub fn recommendations(allocator: Allocator, client: *Client, console: *Console) !void {
    const response = try client.listRecommendations();
    defer response.destroy(allocator);

    const all_recommendations = try response.into([]Recommendation, allocator);
    defer all_recommendations.deinit();

    for (all_recommendations.value) |*rec| {
        try rec.setCreatedAt();
    }

    std.mem.sort(Recommendation, all_recommendations.value, {}, Recommendation.lessThan);
    std.mem.reverse(Recommendation, all_recommendations.value);

    const table = try tabulate(
        Recommendation,
        allocator,
        all_recommendations.value,
        &.{"created_at"},
    );
    defer allocator.free(table);

    try console.write(table);
    try console.write("\n");
}
