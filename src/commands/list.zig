const std = @import("std");
const json = std.json;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Client = @import("../Client.zig");

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

fn tabulate(allocator: Allocator, comptime T: type, values: []T, comptime ignored_fields: []const []const u8) !void {
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
    defer table.deinit();
    var writer = table.writer();

    _ = try writer.write(TableElement.Corners.TopLeft);

    for (columns, 0..) |col, idx| {
        _ = try writer.writeBytesNTimes(TableElement.Line.Horizonal, col.max_len);
        if (idx < columns.len - 1)
            _ = try writer.write(TableElement.Junction.HorizontalDown);
    }
    _ = try writer.write(TableElement.Corners.TopRight);
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

    std.log.info("Table Header:\n{s}", .{table.items});
}

const Artist = struct {
    UserId: []const u8,
    ArtistId: []const u8,
    Rating: u8,
    CreatedAt: []const u8,
    UpdatedAt: []const u8,
};

pub fn artists(allocator: Allocator, client: *Client) !void {
    const response = try client.listArtists();
    defer response.destroy(allocator);

    const all_artists = try response.into([]Artist, allocator);
    defer all_artists.deinit();

    try tabulate(
        allocator,
        Artist,
        all_artists.value,
        &.{ "UserId", "CreatedAt", "UpdatedAt" },
    );
}
