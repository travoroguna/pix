const std = @import("std");
const Allocator = std.mem.Allocator;
const bmp = @import("bmp.zig");
const BmpReader = bmp.BmpReader;
const Bmp = bmp.Bmp;
const clap = @import("clap");
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


pub const initial_width: u32 = 1280;
pub const initial_height: u32 = 720;


pub const App = struct {
    allocator: Allocator,
    window: SDL.Window,
    renderer: SDL.Renderer,
    next_time: u32 = 0,
    texture: ?SDL.Texture = null,

    pub fn init(allocator: Allocator) !App {
        try SDL.init(.{
            .video = true,
            .events = true,
            .audio = true,
        });

        var window = try SDL.createWindow(
            "Pix",
            .{ .centered = {} }, .{ .centered = {} },
            1280, 720,
            .{ .vis = .shown, .resizable= true },
        );
        
        var renderer = try SDL.createRenderer(window, null, .{ .accelerated = true });
        return App {
            .allocator=allocator,
            .window=window,
            .renderer=renderer,

        };
    }

    pub fn set_bmp_texture(self: *App, path: []const u8) !void{
        var bmp_reader = BmpReader.init(self.allocator);
        var bmp_f = try bmp_reader.read(path);
        self.texture = try create_sdl_texture_from_bmp(bmp_f, &self.renderer);

        try self.renderer.copy(self.texture.?, null, null);
        self.renderer.present();

        bmp_f.deinit();
    }

    pub fn run(self: *App) !void{
        mainLoop: while (true) {
            self.next_time = SDL.getTicks() + tick_interval;

            while (SDL.pollEvent()) |ev| {
                switch (ev) {
                    .quit => break :mainLoop,

                    .window => |w| {
                        if (w.type == .resized) {
                            if (self.texture) |t| {
                                try self.renderer.copy(t, null, null);
                                self.renderer.present();
                            }
                        }
                    },
                    else => {}
                }
            }


            SDL.delay(time_left(self.next_time));
            self.next_time += tick_interval;
        }
    }

    pub fn deinit(self: *App) void{
        if (self.texture) |t| t.destroy();
        self.renderer.destroy();
        self.window.destroy();
        SDL.quit();
    }

};