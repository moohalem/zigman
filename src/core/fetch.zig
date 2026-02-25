const std = @import("std");

pub fn fetchAndSaveJson(allocator: std.mem.Allocator, dir: std.fs.Dir, filename: []const u8, url: []const u8) !void {
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    var file = try dir.createFile(filename, .{});
    defer file.close();

    var file_buffer: [8192]u8 = undefined;
    var file_writer = file.writer(&file_buffer);

    const fetch_res = try client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .response_writer = &file_writer.interface,
    });

    if (fetch_res.status != .ok) return error.DownloadFailed;

    try file_writer.interface.flush();
}

pub fn fetchMirrors(allocator: std.mem.Allocator, url: []const u8) !std.ArrayListUnmanaged([]const u8) {
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    var response_body: std.io.Writer.Allocating = .init(allocator);
    defer response_body.deinit();

    const fetch_res = try client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .response_writer = &response_body.writer,
    });

    if (fetch_res.status != .ok) return error.DownloadFailed;

    const body_bytes = try response_body.toOwnedSlice();
    defer allocator.free(body_bytes);

    var list: std.ArrayListUnmanaged([]const u8) = .empty;
    errdefer {
        for (list.items) |m| allocator.free(m);
        list.deinit(allocator);
    }

    var it = std.mem.splitScalar(u8, body_bytes, '\n');
    while (it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \r");
        if (trimmed.len > 0 and !std.mem.startsWith(u8, trimmed, "#")) {
            const copy = try allocator.dupe(u8, trimmed);
            try list.append(allocator, copy);
        }
    }

    if (list.items.len == 0) return error.NoMirrorsFound;

    // Shuffle the mirrors
    var prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.timestamp())));
    const random = prng.random();
    random.shuffle([]const u8, list.items);

    return list;
}
