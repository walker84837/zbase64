const std = @import("std");
const parser = @import("args");
const base64 = std.base64;

pub const VERSION = "0.1.0";

fn printUsage(executable_name: ?[:0]const u8) void {
    const name = executable_name orelse "";

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

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const parsed = parser.parseForCurrentProcess(struct {
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
    }, allocator, .print) catch |err| {
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

    var r: std.fs.File.Reader = undefined;

    if (std.mem.eql(u8, infile, "-")) {
        r = std.io.getStdIn().reader();
    } else {
        const file = try std.fs.cwd().openFile(infile, .{ .mode = .read_only });
        defer file.close();
        r = file.reader();
    }
    const reader = r;

    const stdout = std.io.getStdOut().writer();

    const input = try reader.readAllAlloc(allocator, 4096);
    defer allocator.free(input);

    if (opts.decode) {
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
    } else {
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
}

pub fn min(a: anytype, b: anytype) @TypeOf(a, b) {
    return if (a < b) a else b;
}

test "minimum" {
    var minimum_value: i32 = min(1, 2);
    try std.testing.expectEqual(minimum_value, 1);

    minimum_value = min(2, 1);
    try std.testing.expectEqual(minimum_value, 1);
}
