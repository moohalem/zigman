const std = @import("std");

pub fn extractArchive(allocator: std.mem.Allocator, dir: std.fs.Dir, archive_name: []const u8, version: []const u8) !void {
    var archive_file = try dir.openFile(archive_name, .{});
    defer archive_file.close();

    // xz decompressor uses the old GenericReader interface
    const file_reader = archive_file.deprecatedReader();

    // Decompress xz
    var decompressor = try std.compress.xz.decompress(allocator, file_reader);
    defer decompressor.deinit();

    // Bridge the xz decompressor's GenericReader to new std.Io.Reader via adaptToNewApi
    const decomp_reader = decompressor.reader();
    var adapter_buf: [8192]u8 = undefined;
    var adapter = decomp_reader.adaptToNewApi(&adapter_buf);

    // Set up tar iterator with the new Io.Reader interface
    var file_name_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var link_name_buffer: [std.fs.max_path_bytes]u8 = undefined;

    var tar_iter: std.tar.Iterator = .init(&adapter.new_interface, .{
        .file_name_buffer = &file_name_buffer,
        .link_name_buffer = &link_name_buffer,
    });

    while (try tar_iter.next()) |entry| {
        const first_slash_idx = std.mem.indexOf(u8, entry.name, "/") orelse continue;
        const stripped_path = entry.name[first_slash_idx + 1 ..];

        if (stripped_path.len == 0) continue;

        const dest_path = try std.fs.path.join(allocator, &[_][]const u8{ version, stripped_path });
        defer allocator.free(dest_path);

        switch (entry.kind) {
            .directory => try dir.makePath(dest_path),
            .file => {
                if (std.fs.path.dirname(dest_path)) |parent_dir| {
                    try dir.makePath(parent_dir);
                }

                var out_file = try dir.createFile(dest_path, .{});
                defer out_file.close();

                var write_buf: [8192]u8 = undefined;
                var out_writer = out_file.writer(&write_buf);
                try tar_iter.streamRemaining(entry, &out_writer.interface);
                try out_writer.interface.flush();

                if (std.mem.eql(u8, std.fs.path.basename(dest_path), "zig")) {
                    const stat = try out_file.stat();
                    try out_file.chmod(stat.mode | 0o111);
                }
            },
            else => {},
        }
    }
}
