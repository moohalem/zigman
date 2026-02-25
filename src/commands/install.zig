const std = @import("std");
const builtin = @import("builtin");

const downloader = @import("../core/downloader.zig");
const extractor = @import("../core/extractor.zig");

pub fn execute(allocator: std.mem.Allocator, version: []const u8, force: bool) !void {
    std.debug.print("* Preparing to install Zig {s}...\n", .{version});

    const home_dir = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_dir);

    const zigman_path = try std.fs.path.join(allocator, &[_][]const u8{ home_dir, ".zigman" });
    defer allocator.free(zigman_path);

    var zigman_dir = try std.fs.cwd().makeOpenPath(zigman_path, .{});
    defer zigman_dir.close();

    const json_filename = "versions.json";

    zigman_dir.access(json_filename, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("  versions.json not found. Fetching from ziglang.org...\n", .{});
            try fetchAndSaveJson(allocator, zigman_dir, json_filename);
        },
        else => return err,
    };

    if (zigman_dir.access(version, .{})) |_| {
        if (!force) {
            std.debug.print("Warning: Version {s} is already installed.\n", .{version});
            std.debug.print("Use the -f or --force flag to reinstall.\n", .{});
            return;
        } else {
            std.debug.print("  Force flag detected. Deleting existing {s} directory...\n", .{version});
            try zigman_dir.deleteTree(version);
        }
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    }

    const max_bytes = 5 * 1024 * 1024;
    const json_bytes = try zigman_dir.readFileAlloc(allocator, json_filename, max_bytes);
    defer allocator.free(json_bytes);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_bytes, .{});
    defer parsed.deinit();

    const root = parsed.value.object;
    const version_obj = root.get(version) orelse {
        std.debug.print("Error: Version '{s}' not found in versions.json.\n", .{version});
        return error.VersionNotFound;
    };

    const target_key = try std.fmt.allocPrint(allocator, "{s}-{s}", .{ @tagName(builtin.cpu.arch), @tagName(builtin.os.tag) });
    defer allocator.free(target_key);

    const target_obj = version_obj.object.get(target_key) orelse {
        std.debug.print("Error: No binary available for {s}.\n", .{target_key});
        return error.TargetNotSupported;
    };

    const tarball_url = target_obj.object.get("tarball").?.string;
    const last_slash = std.mem.lastIndexOf(u8, tarball_url, "/") orelse return error.InvalidUrl;
    const file_name = tarball_url[last_slash + 1 ..];

    // ==========================================
    // STEP 4: Download and Extract (FIXED calls)
    // ==========================================
    std.debug.print("  Downloading {s}...\n", .{file_name});

    // Use the downloader module
    try downloader.downloadFile(allocator, zigman_dir, tarball_url, file_name);

    std.debug.print("  Extracting into ~/.zigman/{s}/ ...\n", .{version});

    // Use the extractor module
    try extractor.extractArchive(allocator, zigman_dir, file_name, version);

    // Clean up the downloaded tarball after extraction
    try zigman_dir.deleteFile(file_name);

    std.debug.print("\n* Successfully installed Zig {s}!\n", .{version});
}

fn fetchAndSaveJson(allocator: std.mem.Allocator, dir: std.fs.Dir, filename: []const u8) !void {
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    const uri = try std.Uri.parse("https://ziglang.org/download/index.json");
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
    while (true) {
        const bytes_read = try req.read(&buffer);
        if (bytes_read == 0) break;
        try file.writeAll(buffer[0..bytes_read]);
    }
}
