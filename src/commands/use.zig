const std = @import("std");

pub fn execute(allocator: std.mem.Allocator, version: []const u8) !void {
    // 1. Resolve the user's home directory
    const home_dir = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_dir);

    // 2. Check if the version is actually installed
    const version_binary = try std.fs.path.join(allocator, &[_][]const u8{ home_dir, ".zigman", version, "zig" });
    defer allocator.free(version_binary);

    std.fs.cwd().access(version_binary, .{}) catch |err| switch (err) {
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

    // 4. Remove the old symlink if it exists
    bin_dir.deleteFile("zig") catch |err| switch (err) {
        error.FileNotFound => {}, // This is fine; it means there's no active version yet
        else => return err,
    };

    // 5. Create the new symlink using a relative path (../\<version\>/zig)
    const relative_target = try std.fs.path.join(allocator, &[_][]const u8{ "..", version, "zig" });
    defer allocator.free(relative_target);

    try bin_dir.symLink(relative_target, "zig", .{});

    std.debug.print("* Successfully set Zig to version {s}\n", .{version});
}
