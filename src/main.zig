const std = @import("std");

const cmd_fetch = @import("commands/fetch.zig");
const cmd_install = @import("commands/install.zig");
const cmd_list = @import("commands/list.zig");
const cmd_uninstall = @import("commands/uninstall.zig");
const cmd_use = @import("commands/use.zig");

const APP_VERSION = "v1.0.0";

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
    \\      A very simple Zig version manager. Written in Zig.
    \\
    \\COMMANDS:
    \\      install <version> [optional -f or --force flag] - Install a specific Zig version
    \\      uninstall <version> - Uninstall a specific Zig version
    \\      list - List installed Zig versions
    \\      fetch - Fetch list of available Zig versions
    \\      use <version> - Use a specific Zig version
    \\      help | h - Display this help message
    \\      version | v - Display the current Zig version
    \\
    \\AUTHOR:
    \\      Mohammad Alamsyah/moohalem <mohalem.public@gmail.com>
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
                    std.debug.print("Error: 'Install' requires version argument\n", .{});
                    return;
                }
                const version = args[2];

                // Simple check for the force flag
                var force = false;
                if (args.len >= 4) {
                    if (std.mem.eql(u8, args[3], "-f") or std.mem.eql(u8, args[3], "--force")) {
                        force = true;
                    }
                }

                try cmd_install.execute(allocator, version, force);
            },
            .uninstall => {
                if (args.len < 3) {
                    std.debug.print("Error: 'Uninstall' requires a number or version argument", .{});
                    return;
                }
                const target = args[2];
                try cmd_uninstall.execute(allocator, target);
            },
            .list => {
                try cmd_list.execute(allocator);
            },
            .fetch => try cmd_fetch.fetchVersions(allocator),
            .use => {
                if (args.len < 3) {
                    std.debug.print("Error: 'Use' requires version argument\n", .{});
                    return;
                }
                const version = args[2];
                try cmd_use.execute(allocator, version);
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
