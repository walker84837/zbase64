const std = @import("std");
const base64Encoder = std.base64.Base64Encoder;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const encoder = base64Encoder.init(std.base64.standard_alphabet_chars, '=');

    const input = std.io.getStdIn().reader();
    const inputBuffer = try input.readAllAlloc(allocator, 1024);
    defer allocator.free(inputBuffer);

    const encodedSize = base64Encoder.calcSize(&encoder, inputBuffer.len);
    const encodedBuffer = try allocator.alloc(u8, encodedSize);
    defer allocator.free(encodedBuffer);

    const encodedSlice = base64Encoder.encode(&encoder, encodedBuffer, inputBuffer);

    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll(encodedSlice);
}
