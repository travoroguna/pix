const std = @import("std");
const Allocator = std.mem.Allocator;
const bmp = @import("bmp.zig");
const BmpReader = bmp.BmpReader;
const Bmp = bmp.Bmp;

const SDL = @import("sdl2");


const tick_interval = 60;

fn time_left(next_time: u32) u32{
    var now = SDL.getTicks();

    if (next_time <= now) {
        return 0;
    }
    return next_time - now;

}


pub fn create_sdl_texture_from_bmp(b: *Bmp, renderer: *SDL.Renderer) !SDL.Texture{
    var surface = try SDL.createRgbSurfaceWithFormat(
        @intCast(u31, b.info_header.width),
        @intCast(u31, b.info_header.height),
        .rgb555
    );

    var b_renderer = try SDL.createSoftwareRenderer(surface);

    var y: u32 = 0;
    var x: u32 = b.info_header.width-1;
    var x_actual: u32 = 0;

    while (y < b.info_header.height) {
        while (x > 0 ) {
            var color = b.get_pixel_rgb(x, y).*;
            try b_renderer.setColor(SDL.Color.rgb(color[0], color[1], color[2]));
            try b_renderer.drawPoint(@intCast(i32, x_actual), @intCast(i32, y));
            x-=1;
            x_actual += 1;
        }

        y+=1;
        x_actual = 0;
        x=b.info_header.width - 1;
    }

    var texture = try SDL.createTextureFromSurface(renderer.*, surface);
    return texture;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    var bmp_reader = BmpReader.init(allocator);
    var bmp_f = try bmp_reader.read("image.bmp");

    var next_time: u32 = 0;

    try SDL.init(.{
        .video = true,
        .events = true,
        .audio = true,
    });
    defer SDL.quit();

    var window = try SDL.createWindow(
        "BMP viewer",
        .{ .centered = {} }, .{ .centered = {} },
        bmp_f.info_header.width, bmp_f.info_header.height,
        .{ .vis = .shown, .resizable= true },
    );

    defer window.destroy();

    var renderer = try SDL.createRenderer(window, null, .{ .accelerated = true });
    defer renderer.destroy();

    var texture = try create_sdl_texture_from_bmp(bmp_f, &renderer);
    defer texture.destroy();

    
    try renderer.copy(texture, null, null);
    renderer.present();

    bmp_f.deinit();

    mainLoop: while (true) {
        next_time = SDL.getTicks() + tick_interval;

        while (SDL.pollEvent()) |ev| {
            switch (ev) {
                .quit => break :mainLoop,

                .window => |w| {
                    if (w.type == .resized) {
                        // var size = w.type.resized;
                        // var rect = SDL.Rectangle {.x=0, .y=0, .width=size.width, .height=size.height};
                        try renderer.copy(texture, null, null);
                        renderer.present();
                    }
                },
                else => {}
            }
        }

        // try renderer.setColorRGB(0xF7, 0xA4, 0x1D);
        // try renderer.clear();

        SDL.delay(time_left(next_time));
        next_time += tick_interval;
    }
}
