const std = @import("std");
const Allocator = std.mem.Allocator;
const clap = @import("clap");
const App = @import("app.zig").App;




pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    const params = comptime clap.parseParamsComptime(
        \\<FILE>              Image file to open
        \\-h, --help          Display this help message and exits
        \\
    );


    const parsers = comptime .{
        .FILE = clap.parsers.string,
    };

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, &parsers, .{
        .diagnostic = &diag,
    }) catch |err| {
        // Report useful error and exit
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return;
    };

    defer res.deinit();

    if (res.args.help or res.positionals.len != 1) {
        std.debug.print("Usage:", .{});
        try clap.usage(std.io.getStdErr().writer(), clap.Help, &params);
        std.debug.print("\n", .{});
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    var app = try App.init(allocator);
    defer app.deinit();

    app.set_bmp_texture(res.positionals[0]) catch |err| {
        std.debug.print("Error opening file: {}\n", .{err});
    };
    try app.run();
   
}
