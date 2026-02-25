const std = @import("std");

pub fn extractArchive(allocator: std.mem.Allocator, dir: std.fs.Dir, archive_name: []const u8, version: []const u8) !void {
    var archive_file = try dir.openFile(archive_name, .{});
    defer archive_file.close();

    var decompressor = try std.compress.xz.decompress(allocator, archive_file.reader());
    defer decompressor.deinit();

    var tar_iter = std.tar.iterator(decompressor.reader(), .{});

    while (try tar_iter.next()) |entry| {
        const first_slash_idx = std.mem.indexOf(u8, entry.name, "/") orelse continue;
        const stripped_path = entry.name[first_slash_idx + 1 ..];

        if (stripped_path.len == 0) continue;

        const dest_path = try std.fs.path.join(allocator, &[_][]const u8{ version, stripped_path });
        defer allocator.free(dest_path);

        switch (entry.kind) {
            .directory => try dir.makePath(dest_path),
            .normal => {
                if (std.fs.path.dirname(dest_path)) |parent_dir| {
                    try dir.makePath(parent_dir);
                }

                var out_file = try dir.createFile(dest_path, .{});
                defer out_file.close();

                var buffer: [8192]u8 = undefined;
                while (true) {
                    const bytes_read = try entry.reader().read(&buffer);
                    if (bytes_read == 0) break;
                    try out_file.writeAll(buffer[0..bytes_read]);
                }

                if (std.mem.endsWith(u8, dest_path, "/zig")) {
                    const stat = try out_file.stat();
                    try out_file.chmod(stat.mode | 0o111);
                }
            },
            else => {},
        }
    }
}
