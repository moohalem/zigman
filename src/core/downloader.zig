const std = @import("std");

pub fn downloadFile(allocator: std.mem.Allocator, dir: std.fs.Dir, url: []const u8, filename: []const u8) !void {
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    var file = try dir.createFile(filename, .{});
    defer file.close();
    errdefer dir.deleteFile(filename) catch {};

    var file_buffer: [8192]u8 = undefined;
    var file_writer = file.writer(&file_buffer);

    std.debug.print("    Downloading... (this may take a moment)\n", .{});

    const fetch_res = client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .redirect_behavior = @enumFromInt(5), // Follow up to 5 redirects
        .response_writer = &file_writer.interface,
    }) catch |err| {
        return err; // Forward fetch error
    };

    if (fetch_res.status != .ok) {
        return error.DownloadFailed;
    }

    try file_writer.interface.flush();
}
