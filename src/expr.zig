pub const VarExpr = struct {
    name: []const u8,
};

pub fn AppExpr(comptime ExprT: type) type {
    return struct {
        left: *ExprT,
        right: *ExprT,
    };
}

pub fn LambdaExpr(comptime ExprT: type) type {
    return struct {
        boundVar: []const u8,
        body: *ExprT,
    };
}

pub const Expression = union(enum) {
    variable: VarExpr,
    application: AppExpr(Expression),
    lambda: LambdaExpr(Expression),
};

pub fn print(out: anytype, expr: *const Expression) !void {
    switch (expr.*) {
        .variable => |v| {
            _ = try out.write(v.name);
        },
        .application => |app| {
            _ = try out.write("(");
            try print(out, app.left);
            _ = try out.write(" ");
            try print(out, app.right);
            _ = try out.write(")");
        },
        .lambda => |l| {
            _ = try out.write("\\");
            _ = try out.write(l.boundVar);
            _ = try out.write(". ");
            try print(out, l.body);
        },
    }
}
