const std = @import("std");
const fetch = @import("../core/fetch.zig");

pub fn fetchVersions(allocator: std.mem.Allocator) !void {
    // ==========================================
    // STEP 1: Resolve Paths and Open ~/.zigman/
    // ==========================================
    const home_dir = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_dir);

    const zigman_path = try std.fs.path.join(allocator, &[_][]const u8{ home_dir, ".zigman" });
    defer allocator.free(zigman_path);

    var zigman_dir = try std.fs.cwd().makeOpenPath(zigman_path, .{});
    defer zigman_dir.close();

    // ==========================================
    // STEP 2: Read and Parse config.json
    // ==========================================
    zigman_dir.access("config.json", .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("  config.json not found. Downloading from GitHub...\n", .{});
            try fetch.fetchAndSaveJson(allocator, zigman_dir, "config.json", "https://raw.githubusercontent.com/moohalem/zigman/main/config.json");
        },
        else => return err,
    };

    const config_bytes = try zigman_dir.readFileAlloc(allocator, "config.json", 1024 * 1024);
    defer allocator.free(config_bytes);

    const config_parsed = try std.json.parseFromSlice(std.json.Value, allocator, config_bytes, .{});
    defer config_parsed.deinit();

    // Safely extract the versionMapUrl
    const url_val = config_parsed.value.object.get("versionMapUrl") orelse {
        std.debug.print("Error: 'versionMapUrl' not found in config.json\n", .{});
        return error.InvalidConfig;
    };
    const url = url_val.string;

    // ==========================================
    // STEP 3: Fetch the JSON from the Dynamic URL
    // ==========================================
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    var response_body: std.io.Writer.Allocating = .init(allocator);
    defer response_body.deinit();

    std.debug.print("* Fetching available versions from {s}...\n", .{url});

    const fetch_buffer = try client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .response_writer = &response_body.writer,
    });

    if (fetch_buffer.status != .ok) {
        std.debug.print("Error: Failed to fetch. HTTP Status: {}\n", .{fetch_buffer.status});
        return error.HttpFetchFailed;
    }

    const body_bytes = try response_body.toOwnedSlice();
    defer allocator.free(body_bytes);

    // ==========================================
    // STEP 4: Save to versions.json (Overwrites old)
    // ==========================================
    // std.fs.Dir.createFile truncates by default, cleanly replacing old files
    var version_file = try zigman_dir.createFile("versions.json", .{});
    defer version_file.close();

    try version_file.writeAll(body_bytes);
    std.debug.print("* Saved index to ~/.zigman/versions.json\n", .{});

    // ==========================================
    // STEP 5: Parse and Display the Output
    // ==========================================
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, body_bytes, .{});
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) {
        std.debug.print("Error: Expected JSON object at root.\n", .{});
        return error.InvalidJsonFormat;
    }

    std.debug.print("\n--- Available Zig Versions ---\n", .{});

    var it = root.object.iterator();
    while (it.next()) |entry| {
        const version_name = entry.key_ptr.*;

        if (std.mem.eql(u8, version_name, "master")) continue;

        std.debug.print("- {s}\n", .{version_name});
    }
}
