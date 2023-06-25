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
        //std.debug.print("lambda:     {}\n", .{self});
        //std.debug.print("exprs size: {}\n", .{exprs.items.len});
        const e = exprs.items[self.lambda.body];
        //std.debug.print("body:       {}\n", .{e});
        const idx = try e.substitut(self.lambda.boundVar, expr);
        //std.debug.print("index:      {}\n", .{idx});
        //std.debug.print("exprs size: {}\n", .{exprs.items.len});
        return idx;
    }

    pub fn addVariable(name: []const u8) !usize {
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

    fn substitut(self: Self, name: []const u8, expr: usize) !usize {
        return switch (self) {
            .lambda => |l| if (!std.mem.eql(u8, l.boundVar, name)) b: {
                const body = exprs.items[l.body];
                break :b addLambda(l.boundVar, try body.substitut(name, expr));
            } else @intFromPtr(&self) - @intFromPtr(&exprs.items[0]),
            .application => |a| b: {
                const left = exprs.items[a.left];
                const right = exprs.items[a.right];
                break :b addApplication(try left.substitut(name, expr), try right.substitut(name, expr));
            },
            .variable => |v| if (std.mem.eql(u8, v.name, name)) expr else (findVariable(v.name) orelse return error.VariableNotFound),
        };
    }

    pub fn eval(self: Self) Expression {
        //std.debug.print("{}\n", .{self});
        return switch (self) {
            .application => |a| switch (exprs.items[a.left]) {
                .lambda => b: {
                    //std.debug.print("\n(eval) exprs size: {}\n", .{exprs.items.len});
                    const idx = exprs.items[a.left].apply(a.right) catch unreachable;
                    //std.debug.print("(eval) exprs size: {}\n", .{exprs.items.len});
                    const out = exprs.items[idx];
                    break :b out;
                }, // TODO: might fail to allocate
                else => self,
            },
            else => |e| e,
        };
    }
};

pub fn print(out: anytype, e: *const Expression) !void {
    switch (e.*) {
        .variable => |v| {
            _ = try out.write(v.name);
        },
        .application => |app| {
            _ = try out.write("(");
            try print(out, &exprs.items[app.left]);
            _ = try out.write(" ");
            try print(out, &exprs.items[app.right]);
            _ = try out.write(")");
        },
        .lambda => |l| {
            _ = try out.write("\\");
            _ = try out.write(l.boundVar);
            _ = try out.write(". ");
            try print(out, &exprs.items[l.body]);
        },
    }
}
