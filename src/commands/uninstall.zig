const std = @import("std");

fn cmpStrings(context: void, a: []const u8, b: []const u8) bool {
    _ = context;
    return std.mem.order(u8, a, b) == .lt;
}

pub fn execute(allocator: std.mem.Allocator, target: []const u8) !void {
    const home_dir = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_dir);

    const zigman_path = try std.fs.path.join(allocator, &[_][]const u8{ home_dir, ".zigman" });
    defer allocator.free(zigman_path);

    var zigman_dir = try std.fs.cwd().openDir(zigman_path, .{ .iterate = true });
    defer zigman_dir.close();

    var target_version: []const u8 = target;
    var is_allocated = false;

    // STEP 1: Determine if the user typed a number (index) or a string (version)
    if (std.fmt.parseInt(usize, target, 10)) |index| {
        if (index == 0) {
            std.debug.print("Error: Invalid index 0. Numbering starts at 1.\n", .{});
            return;
        }

        // It is a number! Let's build the sorted list to find out which version it is.
        var versions: std.ArrayListUnmanaged([]const u8) = .empty;
        defer {
            for (versions.items) |v| allocator.free(v);
            versions.deinit(allocator);
        }

        var iter = zigman_dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .directory and !std.mem.eql(u8, entry.name, "bin")) {
                try versions.append(allocator, try allocator.dupe(u8, entry.name));
            }
        }

        std.mem.sort([]const u8, versions.items, {}, cmpStrings);

        if (index > versions.items.len) {
            std.debug.print("Error: Index [{d}] is out of bounds. You only have {d} versions installed.\n", .{ index, versions.items.len });
            return;
        }

        // Grab the actual version string (adjusting for 0-based array indexing)
        target_version = try allocator.dupe(u8, versions.items[index - 1]);
        is_allocated = true; // Flag so we remember to free this specific string later

    } else |_| {
        // parseInt failed (e.g., they typed "0.14.0"), so we just treat it as the literal string.
    }

    // Clean up our dynamically allocated string if we generated one from the index
    defer if (is_allocated) allocator.free(target_version);

    // STEP 2: Verify the target directory exists
    zigman_dir.access(target_version, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Error: Version '{s}' is not currently installed.\n", .{target_version});
            return;
        },
        else => return err,
    };

    // STEP 3: Delete the version directory
    std.debug.print("* Uninstalling Zig version {s}...\n", .{target_version});
    try zigman_dir.deleteTree(target_version);

    // Optional Check: If they deleted the currently active version, the symlink in `bin/` is now dead.
    // In a future update, you could read the symlink and delete it if it points to this folder!

    std.debug.print("* Successfully uninstalled!\n", .{});
}
