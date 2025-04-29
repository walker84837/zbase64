const std = @import("std");
const parser = @import("args");
const base64 = std.base64;

pub const VERSION = "0.1.0";

const Base64Error = error{InvalidInput};

fn printUsage(executable_name: ?[:0]const u8) void {
    const name = executable_name orelse "zbase64";

    std.debug.print(
        "Usage: {s} [OPTION]... [FILE]\n" ++
            "With no FILE, or when FILE is -, read standard input.\n\n" ++
            "Mandatory arguments to long options are mandatory for short options too.\n" ++
            "  -d, --decode          decode data\n" ++
            "  -i, --ignore-garbage  when decoding, ignore non-alphabet characters\n" ++
            "  -w, --wrap=COLS       wrap encoded lines after COLS characters (default 76).\n" ++
            "                          Use 0 to disable line wrapping\n" ++
            "      --help            display this help and exit\n" ++
            "      --version         output version information and exit\n",
        .{name},
    );
}

const Options = struct {
    decode: bool = false,
    @"ignore-garbage": bool = false,
    wrap: usize = 76,
    help: bool = false,
    version: bool = false,

    pub const shorthands = .{
        .d = "decode",
        .i = "ignore-garbage",
        .w = "wrap",
    };
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const parsed = parser.parseForCurrentProcess(Options, allocator, .print) catch |err| {
        std.debug.print("Error parsing options: {}\n", .{err});
        return;
    };
    defer parsed.deinit();

    const opts = parsed.options;
    const executable_name = parsed.executable_name;
    if (opts.help) {
        printUsage(executable_name);
        return;
    }
    if (opts.version) {
        std.debug.print("{s}\n", .{VERSION});
        return;
    }

    const infile = if (parsed.positionals.len > 0) parsed.positionals[0] else "-";

    var input: []const u8 = undefined;

    if (std.mem.eql(u8, infile, "-")) {
        const stdin_reader = std.io.getStdIn().reader();
        input = try stdin_reader.readAllAlloc(allocator, 4096);
    } else {
        input = try std.fs.cwd().readFileAlloc(allocator, infile, 4096);
    }

    if (!isBase64Valid(input) and opts.decode) {
        return Base64Error.InvalidInput;
    }

    defer allocator.free(input);

    const stdout = std.io.getStdOut().writer();

    // now dispatch to encode/decode just as before:
    if (opts.decode) {
        try decodeBase64(allocator, opts, input, stdout);
    } else {
        try encodeBase64(allocator, opts, input, stdout);
    }
}

fn encodeBase64(allocator: std.mem.Allocator, opts: Options, input: []const u8, stdout: std.fs.File.Writer) !void {
    var encoder = base64.Base64Encoder.init(base64.standard_alphabet_chars, '=');
    const encoder_size = encoder.calcSize(input.len);
    const encoder_buffer = try allocator.alloc(u8, encoder_size);
    const encoder_slice = encoder.encode(encoder_buffer, input);

    if (opts.wrap != 0) {
        var idx: usize = 0;
        while (idx < encoder_slice.len) : (idx += opts.wrap) {
            const len = min(opts.wrap, encoder_slice.len - idx);
            try stdout.writeAll(encoder_slice[idx..][0..len]);
            try stdout.writeAll("\n");
        }
    } else {
        try stdout.writeAll(encoder_slice);
    }
}

fn decodeBase64(allocator: std.mem.Allocator, opts: Options, input: []const u8, stdout: std.fs.File.Writer) !void {
    var ignore_buffer: [4]u8 = undefined;
    ignore_buffer[0] = '\n';
    ignore_buffer[1] = '\r';
    var ignore_len: usize = 2;

    if (opts.@"ignore-garbage") {
        ignore_buffer[2] = ' ';
        ignore_buffer[3] = '\t';
        ignore_len = 4;
    }

    const ignore_list = ignore_buffer[0..ignore_len];

    var decoder = base64.Base64DecoderWithIgnore.init(base64.standard_alphabet_chars, '=', ignore_list);
    const max_output = try decoder.calcSizeUpperBound(input.len);
    const output_buffer = try allocator.alloc(u8, max_output);
    const output_length = try decoder.decode(output_buffer, input);
    try stdout.writeAll(output_buffer[0..output_length]);
}

pub fn isBase64Valid(input: []const u8) bool {
    const decoder = base64.Base64Decoder.init(base64.standard_alphabet_chars, '=');

    // check if string is empty
    if (input.len == 0) {
        return false;
    }

    // a base 64 string must have a length that is a multiple of 4
    if (input.len % 4 != 0) {
        return false;
    }

    // calculate the size of the decoded string, if it is valid
    const decoded_size = decoder.calcSizeForSlice(input) catch {
        return false;
    };

    // create a buffer to attempt decoding
    var stack_buffer: [1024]u8 = undefined;
    var heap_buffer: []u8 = undefined;
    const buffer = if (decoded_size <= stack_buffer.len) blk: {
        break :blk &stack_buffer;
    } else blk: {
        heap_buffer = std.heap.page_allocator.alloc(u8, decoded_size) catch return false;
        break :blk heap_buffer;
    };
    defer if (decoded_size > stack_buffer.len) {
        std.heap.page_allocator.free(heap_buffer);
    };

    // attempt to decode the string, if it fails, then it can't certainly be correct
    decoder.decode(buffer[0..decoded_size], input) catch {
        return false;
    };

    // if all these tests pass, then the string is valid
    return true;
}

fn min(a: anytype, b: anytype) @TypeOf(a, b) {
    return if (a < b) a else b;
}

test "get minimum of two values" {
    const log = std.log.scoped(.min_test);

    log.warn("Testing min(1, 2)...", .{});
    var minimum_value: i32 = min(1, 2);
    try std.testing.expectEqual(minimum_value, 1);

    log.warn("Testing min(2, 1)...", .{});
    minimum_value = min(2, 1);
    try std.testing.expectEqual(minimum_value, 1);
}

test "isBase64Valid" {
    const log = std.log.scoped(.base64_test);

    const hello_world = "aGVsbG8gd29ybGQ=";
    log.warn("Testing valid base64: '{s}'", .{hello_world});
    try std.testing.expect(isBase64Valid(hello_world));

    const hi_without_newline = "aGk=";
    log.warn("Testing valid base64 (no newline): '{s}'", .{hi_without_newline});
    try std.testing.expect(isBase64Valid(hi_without_newline));

    const hi_with_newline = "aGkK";
    log.warn("Testing valid base64 with newline: '{s}'", .{hi_with_newline});
    try std.testing.expect(isBase64Valid(hi_with_newline));

    const invalid_string = "f2=kfe2e2239130";
    log.warn("Testing invalid base64: '{s}'", .{invalid_string});
    try std.testing.expect(!isBase64Valid(invalid_string));

    log.warn("Testing empty string", .{});
    const empty_string = "";
    try std.testing.expect(!isBase64Valid(empty_string));
}
