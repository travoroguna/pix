const std = @import("std");
const Allocator = std.mem.Allocator;
const BmpReader = @import("bmp.zig").BmpReader;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    var bmp_reader = BmpReader.init(allocator);
    var bmp = try bmp_reader.read("image.bmp");
    defer bmp.deinit();

    
    std.debug.print("{any}\n", .{bmp.info_header});
    std.debug.print("{d}\n", .{bmp.color_data.len});
}
