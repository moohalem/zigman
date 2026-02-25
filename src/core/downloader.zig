const std = @import("std");

pub fn downloadFile(allocator: std.mem.Allocator, dir: std.fs.Dir, url: []const u8, filename: []const u8) !void {
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse(url);
    var header_buf: [8192]u8 = undefined;
    var req = try client.open(.GET, uri, .{ .server_header_buffer = &header_buf });
    defer req.deinit();

    try req.send();
    try req.finish();
    try req.wait();

    if (req.response.status != .ok) return error.DownloadFailed;

    var file = try dir.createFile(filename, .{});
    defer file.close();

    var buffer: [8192]u8 = undefined;
    var total_downloaded: usize = 0;

    while (true) {
        const bytes_read = try req.read(&buffer);
        if (bytes_read == 0) break;
        try file.writeAll(buffer[0..bytes_read]);
        total_downloaded += bytes_read;
        std.debug.print("\r    Downloaded: {d} bytes", .{total_downloaded});
    }
    std.debug.print("\n", .{});
}
