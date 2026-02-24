const std = @import("std");

pub fn fetchVersions(allocator: std.mem.Allocator) !void {
    // Initialize the HTTP Client
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    const url = "https://ziglang.org/download/index.json";

    // --- ZIG 0.15 CHANGE HERE ---
    // We now use the Allocating Writer to dynamically buffer the HTTP stream
    var response_body: std.io.Writer.Allocating = .init(allocator);
    defer response_body.deinit();

    std.debug.print("* Fetching available versions from {s}...\n", .{url});

    // Perform the HTTP GET request
    const fetch_res = try client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        // Pass a pointer to the generic writer interface
        .response_writer = &response_body.writer,
    });

    if (fetch_res.status != .ok) {
        std.debug.print("Error: Failed to fetch. HTTP Status: {}\n", .{fetch_res.status});
        return error.HttpFetchFailed;
    }

    // Extract the raw bytes we just downloaded into a slice
    const body_bytes = try response_body.toOwnedSlice();
    defer allocator.free(body_bytes); // We must free the slice when done

    // Parse the JSON into a dynamic DOM-like structure
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, body_bytes, .{});
    defer parsed.deinit();

    const root = parsed.value;
    if (root != .object) {
        std.debug.print("Error: Expected JSON object at root.\n", .{});
        return error.InvalidJsonFormat;
    }

    std.debug.print("\n--- Available Zig Versions ---\n", .{});

    // Iterate over the keys to print the versions
    var it = root.object.iterator();
    while (it.next()) |entry| {
        const version_name = entry.key_ptr.*;

        // Skip the "master" build if you only want stable releases
        if (std.mem.eql(u8, version_name, "master")) continue;

        std.debug.print("- {s}\n", .{version_name});
    }
}
