const std = @import("std");

// A helper function to sort strings alphabetically
fn cmpStrings(context: void, a: []const u8, b: []const u8) bool {
    _ = context;
    return std.mem.order(u8, a, b) == .lt;
}

pub fn execute(allocator: std.mem.Allocator) !void {
    const home_dir = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_dir);

    const zigman_path = try std.fs.path.join(allocator, &[_][]const u8{ home_dir, ".zigman" });
    defer allocator.free(zigman_path);

    // Open the directory with iteration enabled
    var zigman_dir = std.fs.cwd().openDir(zigman_path, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("No versions installed yet. Run 'zigman install <version>'.\n", .{});
            return;
        }
        return err;
    };
    defer zigman_dir.close();

    // Create an ArrayList to hold our version strings so we can sort them
    var versions: std.ArrayListUnmanaged([]const u8) = .empty;
    defer {
        // We must free every duplicated string before freeing the list itself
        for (versions.items) |v| allocator.free(v);
        versions.deinit(allocator);
    }

    // Iterate through ~/.zigman/
    var iter = zigman_dir.iterate();
    while (try iter.next()) |entry| {
        // We only care about directories, and we specifically ignore the "bin" folder
        if (entry.kind == .directory and !std.mem.eql(u8, entry.name, "bin")) {
            // Duplicate the string so it safely lives in our ArrayList
            const v_name = try allocator.dupe(u8, entry.name);
            try versions.append(allocator, v_name);
        }
    }

    if (versions.items.len == 0) {
        std.debug.print("No Zig versions currently installed.\n", .{});
        return;
    }

    // Sort the list so the numbered output is always stable and predictable
    std.mem.sort([]const u8, versions.items, {}, cmpStrings);

    std.debug.print("\n--- Installed Zig Versions ---\n", .{});

    // Print with the number index (1-based index)
    for (versions.items, 1..) |version, i| {
        std.debug.print("[{d}] {s}\n", .{ i, version });
    }

    std.debug.print("------------------------------\n", .{});
    std.debug.print("To use a version:       zigman use <version>\n", .{});
    std.debug.print("To uninstall a version: zigman uninstall <number|version>\n\n", .{});
}
