const std = @import("std");

const cmd_fetch = @import("commands/fetch.zig");

const APP_VERSION = "v0.0.1";

const Command = enum {
    install,
    uninstall,
    list,
    fetch,
    use,
    help,
    version,
};

const NO_COMMAND =
    \\ZIGMAN - Zig Version Manager
    \\type 'zigman help' for usage information
;

const HELP_TEXT =
    \\NAME:
    \\      ZIGMAN - Zig Version Manager
    \\
    \\USAGE:
    \\      zigman [command]
    \\
    \\VERSION:
    \\      v0.1.0
    \\
    \\DESCRIPTION:
    \\      A simple Zig version manager. Written in Zig.
    \\
    \\COMMANDS:
    \\      install <version> - Install a specific Zig version
    \\      uninstall <version> - Uninstall a specific Zig version
    \\      list - List installed Zig versions
    \\      fetch - Fetch list of available Zig versions
    \\      use <version> - Use a specific Zig version
    \\      help | h - Display this help message
    \\      version | v - Display the current Zig version
    \\
    \\AUTHOR:
    \\      Mohammad Alamsyah/mohalem <mohalem.public@gmail.com>
;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("{s}", .{NO_COMMAND});
        return;
    }

    const cmd_str = args[1];
    if (std.meta.stringToEnum(Command, cmd_str)) |cmd| {
        switch (cmd) {
            .install => {
                if (args.len < 3) {
                    std.debug.print("Error: 'Install' requires version argument", .{});
                    return;
                }
                std.debug.print("*Installing version {s}...\n", .{args[2]});
            },
            .uninstall => {
                if (args.len < 3) {
                    std.debug.print("Error: 'Uninstall' requires version argument", .{});
                    return;
                }
                std.debug.print("*Uninstalling version {s}...\n", .{args[2]});
            },
            .list => {
                std.debug.print("*Listing installed versions...\n", .{});
            },
            .fetch => try cmd_fetch.fetchVersions(allocator),
            .use => {
                if (args.len < 3) {
                    std.debug.print("Error: 'Use' requires version argument", .{});
                    return;
                }
                std.debug.print("*Using version {s}...\n", .{args[2]});
            },
            .help => {
                std.debug.print("{s}", .{HELP_TEXT});
            },
            .version => {
                std.debug.print("Zigman version: {s}\n", .{APP_VERSION});
            },
        }
    } else {
        std.debug.print("Command '{s}' is not recognized.\n", .{cmd_str});
        std.debug.print("Run 'zigman help' for usage information\n", .{});
    }
}
