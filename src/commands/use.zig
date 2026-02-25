const std = @import("std");

pub fn execute(allocator: std.mem.Allocator, version: []const u8) !void {
    // 1. Resolve the user's home directory
    const home_dir = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_dir);

    // 2. Define the path to the installed binary (~/.zigman/<version>/zig)
    const target_binary = try std.fs.path.join(allocator, &[_][]const u8{ home_dir, ".zigman", version, "zig" });
    defer allocator.free(target_binary);

    // Check if the version is actually installed
    std.fs.cwd().access(target_binary, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Error: Version '{s}' is not installed.\n", .{version});
            std.debug.print("Run 'zigman install {s}' first.\n", .{version});
            return;
        },
        else => return err,
    };

    // 3. Prepare the ~/.zigman/bin directory where our symlink will live
    const bin_dir_path = try std.fs.path.join(allocator, &[_][]const u8{ home_dir, ".zigman", "bin" });
    defer allocator.free(bin_dir_path);

    var bin_dir = try std.fs.cwd().makeOpenPath(bin_dir_path, .{});
    defer bin_dir.close();

    // 4. Define the symlink path (~/.zigman/bin/zig)
    const link_path = try std.fs.path.join(allocator, &[_][]const u8{ bin_dir_path, "zig" });
    defer allocator.free(link_path);

    // 5. Remove the old symlink if it exists
    std.fs.cwd().deleteFile(link_path) catch |err| switch (err) {
        error.FileNotFound => {}, // This is fine; it means there's no active version yet
        else => return err,
    };

    // 6. Create the new symlink pointing to the target binary
    try std.fs.cwd().symLink(target_binary, link_path, .{});

    std.debug.print("* Successfully set Zig to version {s}\n", .{version});
}
