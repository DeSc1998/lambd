const std = @import("std");

pub const VarExpr = struct {
    name: []const u8,
};

const AppExpr = struct {
    left: usize,
    right: usize,
};

const LambdaExpr = struct {
    boundVar: []const u8,
    body: usize,
};

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();
pub var exprs = std.ArrayList(Expression).init(allocator);
var last_expr: usize = 0;

pub const Expression = union(enum) {
    variable: VarExpr,
    application: AppExpr,
    lambda: LambdaExpr,

    const Self = @This();

    fn apply(self: Self, expr: usize) !usize {
        std.debug.assert(self == .lambda);
        const e = exprs.items[self.lambda.body];
        const idx = try e.substitut(self.lambda.boundVar, expr);
        return idx;
    }

    pub fn addVariable(name: []const u8) !usize {
        if (findVariable(name)) |idx| {
            return idx;
        }

        const idx = last_expr;
        last_expr += 1;
        var tmp = try exprs.addOne();
        tmp.* = .{
            .variable = VarExpr{
                .name = name,
            },
        };
        return idx;
    }

    pub fn addLambda(v: []const u8, expr: usize) !usize {
        const idx = last_expr;
        last_expr += 1;
        var tmp = try exprs.addOne();
        tmp.* = .{
            .lambda = LambdaExpr{
                .boundVar = v,
                .body = expr,
            },
        };
        return idx;
    }

    pub fn addApplication(left: usize, right: usize) !usize {
        if (findApplication(left, right)) |idx| {
            return idx;
        }

        const idx = last_expr;
        last_expr += 1;
        var tmp = try exprs.addOne();
        tmp.* = .{
            .application = AppExpr{
                .left = left,
                .right = right,
            },
        };
        return idx;
    }

    fn findVariable(name: []const u8) ?usize {
        for (0.., exprs.items) |idx, expr| {
            switch (expr) {
                .variable => |v| if (std.mem.eql(u8, v.name, name)) return idx,
                else => {},
            }
        }
        return null;
    }

    fn findApplication(left: usize, right: usize) ?usize {
        for (0.., exprs.items) |idx, expr| {
            switch (expr) {
                .application => |app| {
                    if (app.left == left and app.right == right) {
                        return idx;
                    }
                },
                else => {},
            }
        }
        return null;
    }

    fn eql(self: Self, other: Self) bool {
        return switch (self) {
            .lambda => |l| b: {
                if (other == .lambda) {
                    const var_eql = std.mem.eql(u8, l.boundVar, other.lambda.boundVar);
                    const body_eql = exprs.items[l.body].eql(exprs.items[other.lambda.body]);
                    break :b var_eql and body_eql;
                } else {
                    break :b false;
                }
            },
            .application => |app| b: {
                if (other == .application) {
                    const e = other.application;
                    const left_eql = exprs.items[app.left].eql(exprs.items[e.left]);
                    const right_eql = exprs.items[app.right].eql(exprs.items[e.right]);
                    break :b left_eql and right_eql;
                } else {
                    break :b false;
                }
            },
            .variable => |v| b: {
                if (other == .variable) {
                    break :b std.mem.eql(u8, v.name, other.variable.name);
                } else {
                    break :b false;
                }
            },
        };
    }

    fn indexOf(target: Self, items: []const Expression) ?usize {
        for (items, 0..) |expr, idx| {
            if (expr.eql(target)) {
                return idx;
            }
        }
        return null;
    }

    fn substitut(self: Self, name: []const u8, expr: usize) !usize {
        return switch (self) {
            .lambda => |l| if (!std.mem.eql(u8, l.boundVar, name)) b: {
                const body = exprs.items[l.body];
                break :b addLambda(l.boundVar, try body.substitut(name, expr));
            } else indexOf(self, exprs.items) orelse 0,
            .application => |a| b: {
                const left = exprs.items[a.left];
                const right = exprs.items[a.right];
                break :b addApplication(try left.substitut(name, expr), try right.substitut(name, expr));
            },
            .variable => |v| if (std.mem.eql(u8, v.name, name)) expr else (findVariable(v.name) orelse return error.VariableNotFound),
        };
    }

    pub fn eval(self: Self) usize {
        return switch (self) {
            .application => |a| switch (exprs.items[a.left]) {
                .lambda => b: {
                    // TODO: might fail to allocate
                    const idx = exprs.items[a.left].apply(a.right) catch unreachable;
                    break :b exprs.items[idx].eval();
                },
                else => b: {
                    const idx = addApplication(exprs.items[a.left].eval(), exprs.items[a.right].eval()) catch unreachable;
                    if (exprs.items[idx].eql(self)) { // nothing changed
                        break :b idx;
                    } else {
                        break :b exprs.items[idx].eval();
                    }
                },
            },
            .lambda => |l| b: {
                const body = exprs.items[l.body];
                const new_body = body.eval();
                break :b addLambda(l.boundVar, new_body) catch unreachable;
            },
            .variable => |v| findVariable(v.name) orelse 0,
        };
    }
};

pub fn print(out: anytype, e: Expression) !void {
    switch (e) {
        .variable => |v| {
            _ = try out.write(v.name);
        },
        .application => |app| {
            _ = try out.write("(");
            try print(out, exprs.items[app.left]);
            _ = try out.write(" ");
            try print(out, exprs.items[app.right]);
            _ = try out.write(")");
        },
        .lambda => |l| {
            _ = try out.write("\\");
            _ = try out.write(l.boundVar);
            _ = try out.write(". ");
            try print(out, exprs.items[l.body]);
        },
    }
}

test "eval-simple_applicaton" {
    const l = @import("lexer.zig");

    const expression = "(a b)";
    var tokens = std.ArrayList(l.Token).init(std.testing.allocator);
    defer tokens.deinit();
    var lexer = l.Lexer.init(expression);
    try lexer.allTokens(&tokens);
    var parser = @import("parser.zig").Parser.init(tokens.items);
    var idx = try parser.parse();
    const expr = exprs.items[idx];

    // is input correctly parsed?
    var inner: [16]u8 = undefined;
    var stream = std.io.fixedBufferStream(&inner);
    var writer = stream.writer();
    try print(writer, expr);
    var buf = stream.getWritten();
    try std.testing.expectEqualSlices(u8, expression, buf);

    // is the expression correctly evaluated?
    idx = expr.eval();
    stream.reset();
    try print(writer, exprs.items[idx]);
    buf = stream.getWritten();
    try std.testing.expectEqualSlices(u8, expression, buf);
}

test "eval-and" {
    const l = @import("lexer.zig");

    const expression = "(\\true. (\\false. (\\x. (\\y. ((x y) false) true) true) \\x. \\y. y) \\x. \\y. x)";
    const expected = "\\x. \\y. x";

    var tokens = std.ArrayList(l.Token).init(std.testing.allocator);
    defer tokens.deinit();
    var lexer = l.Lexer.init(expression);
    try lexer.allTokens(&tokens);
    var parser = @import("parser.zig").Parser.init(tokens.items);
    var idx = try parser.parse();
    const res = exprs.items[idx].eval();

    var inner: [64]u8 = undefined;
    var stream = std.io.fixedBufferStream(&inner);
    var writer = stream.writer();

    try print(writer, exprs.items[res]);
    const buf = stream.getWritten();
    try std.testing.expectEqualSlices(u8, expected, buf);
}

test "eval-or" {
    const l = @import("lexer.zig");

    const expression = "(\\true. (\\false. (\\x. (\\y. ((x true) y) false) false) \\x. \\y. y) \\x. \\y. x)";
    const expected = "\\x. \\y. y";

    var tokens = std.ArrayList(l.Token).init(std.testing.allocator);
    defer tokens.deinit();
    var lexer = l.Lexer.init(expression);
    try lexer.allTokens(&tokens);
    var parser = @import("parser.zig").Parser.init(tokens.items);
    var idx = try parser.parse();
    const res = exprs.items[idx].eval();

    var inner: [64]u8 = undefined;
    var stream = std.io.fixedBufferStream(&inner);
    var writer = stream.writer();

    try print(writer, exprs.items[res]);
    const buf = stream.getWritten();
    try std.testing.expectEqualSlices(u8, expected, buf);
}
