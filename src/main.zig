const std = @import("std");
const lexer = @import("untyped/lexer.zig");
const parser = @import("untyped/parser.zig");
const expr = @import("untyped/expr.zig");

fn collectArgs(args: *std.ArrayList([]const u8)) !void {
    var args_iter = try std.process.argsWithAllocator(args.allocator);
    while (args_iter.next()) |arg| {
        try args.append(arg);
    }
}

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

fn readWholeFile(filename: []const u8) ![]const u8 {
    var cwd = std.fs.cwd();
    const file = try cwd.openFile(filename, .{});
    const stat = try file.stat();
    return cwd.readFileAlloc(allocator, filename, stat.size);
}

const Flags = struct {
    simple_typed: bool = false,
};

fn argsToFlags(args: std.ArrayList([]const u8)) !Flags {
    var flags = Flags{};
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    for (args.items) |arg| {
        if (std.mem.startsWith(u8, arg, "--typed=")) {
            const skip = "--typed=".len;
            const typed = arg[skip..];
            if (std.mem.eql(u8, "simple", typed)) {
                flags.simple_typed = true;
            } else {
                try stdout.print("ERROR: typesystem '{s}' is not defined\n", .{typed});
                try stdout.print("     please use any of these:\n", .{});
                try stdout.print("     simple\n", .{});
                try bw.flush();
                return error.UnsupportedType;
            }
        }
    }

    return flags;
}

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var args = std.ArrayList([]const u8).init(allocator);
    var tokens = std.ArrayList(lexer.Token).init(allocator);
    defer args.deinit();
    defer tokens.deinit();

    try collectArgs(&args);
    const flags = try argsToFlags(args);
    var cwd = std.fs.cwd();

    if (flags.simple_typed) {
        return error.NotImplemented;
    }

    for (args.items[1..]) |arg| {
        cwd.access(arg, std.fs.File.OpenFlags{ .mode = .read_only }) catch |err| {
            try stdout.print("ERROR: {s}: {!}\n", .{ arg, err });
            continue;
        };

        const content = readWholeFile(arg) catch |err| {
            try stdout.print("ERROR: reading file: {}", .{err});
            continue;
        };
        defer allocator.free(content);

        var lexa = lexer.Lexer.init(content);
        lexa.allTokens(&tokens) catch |err| {
            try stdout.print("ERROR: {!}\n", .{err});
            continue;
        };

        var p = parser.Parser.init(tokens.items);

        while (p.parse()) |e| {
            try expr.print(stdout, expr.exprs.items[e]);
            _ = try stdout.write("\n    => ");
            const result = expr.exprs.items[e].eval();
            try expr.print(stdout, expr.exprs.items[result]);
            _ = try stdout.write("\n");
        } else |err| {
            try stdout.print("ERROR: {!}\n", .{err});
        }
    }
    // try expr.printInternalExprs(stdout);
    try bw.flush();
}
