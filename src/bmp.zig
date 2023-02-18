const std = @import("std");
const Allocator = std.mem.Allocator; 
const Tuple = std.meta.Tuple;

pub fn read_file(allocator: Allocator, path: []const u8) ![]u8{
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, (try file.stat()).size);
    
}

const BitCount = enum {
    MonoChrome,
    Palletized4bit,
    Palletized8bit,
    RGB16bit,
    RGB24bit
};

const Compression = enum {
    BL_RGB,
    BL_RLE8,
    BL_RLE4
};  


const InfoHeader = struct {
    file_size: u32,
    width: u32,
    height: u32,
    planes: u16,
    bit_count: BitCount,
    compression: Compression,
    image_size: u32,
    x_pixels_per_meter: u32,
    y_pixels_per_meter: u32,
    colors_used: u32,
    colors_important: u32
};


pub const Color = Tuple(&.{u8, u8, u8});

pub const Bmp = struct {
    data: []u8,
    info_header: InfoHeader,
    allocator: Allocator,
    color_data: []Color,

    pub fn deinit(self: *Bmp) void {
        self.allocator.free(self.data);
        self.allocator.free(self.color_data);
        self.allocator.destroy(self);
    }

    // pub fn get_pixel_hex(self: *Bmp, x: u32, y: u32) u24{
    //     // std.debug.print("x: {d}, y: {d}, x*y: {d}, pos: {d}, color: {d}\n", .{x, y, x*y, self.info_header.width * x + y, self.color_data[x * self.info_header.height + y]});
    //     return self.color_data[x * self.info_header.height + y];
    // } 

    pub fn get_pixel_rgb(self: *Bmp, x: u32, y: u32) *Color{
        return &self.color_data[x + self.info_header.width * y];
    }
};


pub fn to_hex(red: u8, green: u8, blue: u8) u24{
    return ((@intCast(u24, red) & 0xff) << 16) +
           ((@intCast(u24, green) & 0xff) << 8) +
           ((@intCast(u24, blue) & 0xff));
}

pub fn to_rgb(hex_value: u24) Color {
    var r = ((hex_value >> 16) & 0xFF);  // Extract the RR byte
    var g = ((hex_value >> 8) & 0xFF);   // Extract the GG byte
    var b = ((hex_value) & 0xFF);

    return .{@intCast(u8, r), @intCast(u8, g), @intCast(u8, b)};   
}

const BmpReaderError = error {
    OutOfMemory,
    InvalidSignature,
    InvalidBitCount,
    InvalidCompression,
    UnsupportedBitCount,
    UnsupportedCompression
};

pub const BmpReader = struct {
    allocator: Allocator,
    data: []u8 = undefined,

    pub fn init(allocator: Allocator) BmpReader {
        return BmpReader {.allocator=allocator};
    }

    pub fn read(self: *BmpReader, path: []const u8) !*Bmp{
        self.data = try read_file(self.allocator, path);
        errdefer self.allocator.free(self.data);
        return try self.parse_data();
    }


    fn read_u8(self: *BmpReader, offset: usize) u8{
        return self.data[offset];
    }

    fn read_u16(self: *BmpReader, offset: usize) u16{
        var value = @intCast(u16, self.data[offset + 1]) << 8 | self.data[offset];
        return value;
    }

    fn read_u32(self: *BmpReader, offset: usize) u32{
        return @intCast(u32, self.data[offset + 3]) << 24  |
               @intCast(u32, self.data[offset + 2]) << 16  |
               @intCast(u32, self.data[offset + 1]) << 8   |
               @intCast(u32, self.data[offset ])           ;
    }

    fn parse_data(self: *BmpReader) BmpReaderError!*Bmp{
        if (self.data.len < 2 or !std.mem.eql(u8, self.data[0..2], "BM")) {
            return BmpReaderError.InvalidSignature;
        }

        const i_offset = 14;

        var bit_count = switch (self.read_u16(i_offset + 14)) {
            1 => BitCount.MonoChrome,
            4 => BitCount.Palletized4bit,
            8 => BitCount.Palletized8bit,
            16 => BitCount.RGB16bit,
            24 => BitCount.RGB24bit,
            else => return BmpReaderError.InvalidBitCount
        };

        var compression = switch (self.read_u16(i_offset + 16 )) {
            0 => Compression.BL_RGB,
            1 => Compression.BL_RLE4,
            2 => Compression.BL_RLE8,
            else => return BmpReaderError.InvalidCompression
        };


        if (bit_count != .RGB24bit) return BmpReaderError.UnsupportedBitCount;
        if (compression != .BL_RGB) return BmpReaderError.UnsupportedCompression;
        
        var width=self.read_u32(i_offset + 4);
        var height=self.read_u32(i_offset + 8);

        var color_data = try self.allocator.alloc(u24, width * height);

        var count: usize = 0;
        var dt_count: usize = 0;
        const length: usize = self.data[(14+40)..].len;

        while (dt_count < length) {
            color_data[count] = to_hex(self.data[dt_count], self.data[dt_count + 1], self.data[dt_count + 2]);
            count += 1;
            dt_count += 3;
        }


        std.debug.print("calculated: {}, actual: {}\n", .{width*height, (self.data[(14+40)..].len)/3});

        var bmp = try self.allocator.create(Bmp);
        bmp.* = .{
            .data = self.data,
            .allocator=self.allocator,
            .info_header = InfoHeader {
                .file_size=self.read_u32(2),
                .width=width,
                .height=height,
                .planes=self.read_u16(i_offset + 12),
                .bit_count = bit_count,
                .compression=compression,
                .image_size=self.read_u32(i_offset + 20),
                .x_pixels_per_meter=self.read_u32(i_offset + 24),
                .y_pixels_per_meter=self.read_u32(i_offset + 28),
                .colors_used=self.read_u32(i_offset + 32),
                .colors_important=self.read_u32(i_offset + 36)
            },
            .color_data=color_data
        };

        return bmp;
    }
};

