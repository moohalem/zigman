const std = @import("std");
const builtin = @import("builtin");

const downloader = @import("../core/downloader.zig");
const extractor = @import("../core/extractor.zig");
const fetch = @import("../core/fetch.zig");

const minizign = @import("minizign");

pub fn execute(allocator: std.mem.Allocator, version: []const u8, force: bool) !void {
    std.debug.print("* Preparing to install Zig {s}...\n", .{version});

    const home_dir = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home_dir);

    const zigman_path = try std.fs.path.join(allocator, &[_][]const u8{ home_dir, ".zigman" });
    defer allocator.free(zigman_path);

    var zigman_dir = try std.fs.cwd().makeOpenPath(zigman_path, .{});
    defer zigman_dir.close();

    const json_filename = "versions.json";

    // Read config JSON (which was either fetched or exists)
    const config_bytes = zigman_dir.readFileAlloc(allocator, "config.json", 1024 * 1024) catch |err| {
        std.debug.print("Error: Could not read ~/.zigman/config.json.\n", .{});
        return err;
    };
    defer allocator.free(config_bytes);

    const config_parsed = try std.json.parseFromSlice(std.json.Value, allocator, config_bytes, .{});
    defer config_parsed.deinit();

    const mirror_list_url = config_parsed.value.object.get("mirrorListUrl").?.string;
    const minisign_pub_key = config_parsed.value.object.get("minisignPubKey").?.string;

    zigman_dir.access(json_filename, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("  versions.json not found. Fetching from ziglang.org...\n", .{});
            try fetch.fetchAndSaveJson(allocator, zigman_dir, json_filename, "https://ziglang.org/download/index.json");
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

    const tarball_val = target_obj.object.get("tarball") orelse {
        std.debug.print("Error: No tarball URL found for {s} in versions.json.\n", .{target_key});
        return error.TarballNotFound;
    };
    const tarball_url = tarball_val.string;
    const last_slash = std.mem.lastIndexOf(u8, tarball_url, "/") orelse return error.InvalidUrl;
    const file_name = tarball_url[last_slash + 1 ..];

    // ==========================================
    // STEP 4: Download from Mirrors and verify
    // ==========================================
    std.debug.print("  Fetching community mirrors...\n", .{});
    var mirrors = try fetch.fetchMirrors(allocator, mirror_list_url);
    defer {
        for (mirrors.items) |m| allocator.free(m);
        mirrors.deinit(allocator);
    }

    var downloaded = false;

    const prefix = "https://ziglang.org/";
    const url_path = if (std.mem.startsWith(u8, tarball_url, prefix))
        tarball_url[prefix.len..]
    else
        file_name; // Fallback

    for (mirrors.items) |mirror| {
        const base_mirror = if (std.mem.endsWith(u8, mirror, "/")) mirror[0 .. mirror.len - 1] else mirror;

        const full_tarball_url = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_mirror, url_path });
        defer allocator.free(full_tarball_url);

        const full_sig_url = try std.fmt.allocPrint(allocator, "{s}/{s}.minisig", .{ base_mirror, url_path });
        defer allocator.free(full_sig_url);

        const sig_file_name = try std.fmt.allocPrint(allocator, "{s}.minisig", .{file_name});
        defer allocator.free(sig_file_name);

        std.debug.print("  Trying mirror: {s} ...\n", .{base_mirror});

        // 1. Download Tarball
        downloader.downloadFile(allocator, zigman_dir, full_tarball_url, file_name) catch |err| {
            std.debug.print("    Failed to download tarball from mirror: {}\n", .{err});
            continue; // Try next mirror
        };

        // 2. Download Signature
        downloader.downloadFile(allocator, zigman_dir, full_sig_url, sig_file_name) catch |err| {
            std.debug.print("    Failed to download signature from mirror: {}\n", .{err});
            zigman_dir.deleteFile(file_name) catch {}; // cleanup partial
            continue;
        };

        // 3. Verify Signature
        std.debug.print("  Verifying signature...\n", .{});
        if (verifySignature(allocator, zigman_dir, file_name, sig_file_name, minisign_pub_key)) {
            downloaded = true;
            zigman_dir.deleteFile(sig_file_name) catch {};
            break;
        } else |err| {
            std.debug.print("    Signature verification failed: {}\n", .{err});
            zigman_dir.deleteFile(file_name) catch {};
            zigman_dir.deleteFile(sig_file_name) catch {};
            continue;
        }
    }

    if (!downloaded) {
        std.debug.print("Error: Failed to safely download and verify Zig from any mirror.\n", .{});
        return error.AllMirrorsFailed;
    }

    std.debug.print("  Extracting into ~/.zigman/{s}/ ...\n", .{version});

    // Use the extractor module
    try extractor.extractArchive(allocator, zigman_dir, file_name, version);

    // Clean up the downloaded tarball after extraction
    try zigman_dir.deleteFile(file_name);

    std.debug.print("\n* Successfully installed Zig {s}!\n", .{version});
}

fn verifySignature(allocator: std.mem.Allocator, dir: std.fs.Dir, file_name: []const u8, sig_file_name: []const u8, pub_key_str: []const u8) !void {
    const sig_bytes = try dir.readFileAlloc(allocator, sig_file_name, 1024 * 10);
    defer allocator.free(sig_bytes);

    // Decode Signature
    const sig = try minizign.Signature.decode(allocator, sig_bytes);

    // Decode PublicKey
    var pks_buf: [1]minizign.PublicKey = undefined;
    const pks = try minizign.PublicKey.decode(&pks_buf, pub_key_str);
    if (pks.len == 0) return error.NoPublicKeyFound;
    const pk = pks[0];

    // Initialize Verifier
    var verifier = try pk.verifier(&sig);

    var file = try dir.openFile(file_name, .{});
    defer file.close();

    var buf: [65536]u8 = undefined;
    while (true) {
        const bytes_read = try file.read(&buf);
        if (bytes_read == 0) break;
        verifier.update(buf[0..bytes_read]);
    }

    try verifier.verify(allocator);
}
