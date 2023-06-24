const std = @import("std");
const lexer = @import("lexer.zig");

const pError = error{
    UnexpectedToken,
};

const ParserError = lexer.LexerError || pError;

// untyped lambda-calculus
// Def: Term ::= A | (Term Term) | \A. Term

const VarExpr = struct {
    name: []const u8,
};

fn AppExpr(comptime ExprT: type) type {
    return struct {
        left: *ExprT,
        right: *ExprT,
    };
}

fn LambdaExpr(comptime ExprT: type) type {
    return struct {
        boundVar: []const u8,
        body: *ExprT,
    };
}

const Expression = union(enum) {
    variable: VarExpr,
    application: AppExpr(Expression),
    lambda: LambdaExpr(Expression),
};

const Parser = struct {
    current_position: u64,
    tokens: []const lexer.Token,
    allocator: std.mem.Allocator,

    const Kind = lexer.TokenKind;
    const App = AppExpr(Expression);
    const Lambda = LambdaExpr(Expression);
    const Self = @This();

    pub fn init(tokens: []const lexer.Token, alloc: std.mem.Allocator) Self {
        return Self{
            .current_position = 0,
            .tokens = tokens,
            .allocator = alloc,
        };
    }

    pub fn reset(self: *Self) void {
        self.current_position = 0;
    }

    fn expect(self: *Self, kind: Kind) ParserError!lexer.Token {
        if (self.current_position >= self.tokens.len) {
            return ParserError.EndOfFile;
        }

        if (self.tokens[self.current_position].kind == kind) {
            self.current_position += 1;
            return self.tokens[self.current_position - 1];
        } else {
            return ParserError.UnexpectedToken;
        }
    }

    pub fn currentToken(self: *Self) ?lexer.Token {
        return if (self.current_position < self.tokens.len) self.tokens[self.current_position] else null;
    }

    fn parseVariable(self: *Self) ParserError!*Expression {
        const t = try self.expect(Kind.Symbol); // TODO: `Token` needs more metadata for better error reporting
        var tmp = allocator.create(Expression) catch {
            return ParserError.MemoryFailure;
        };
        tmp.* = .{ .variable = VarExpr{
            .name = t.chars,
        } };
        return tmp;
    }

    fn parseApplication(self: *Self) ParserError!*Expression {
        _ = try self.expect(Kind.ApplicationOpen);
        const left = try self.parse();
        const right = try self.parse();
        _ = try self.expect(Kind.ApplicationClose);
        var tmp = allocator.create(Expression) catch {
            return ParserError.MemoryFailure;
        };
        tmp.* = .{ .application = App{
            .left = left,
            .right = right,
        } };
        return tmp;
    }

    fn parseLambda(self: *Self) ParserError!*Expression {
        _ = try self.expect(Kind.LambdaBegin);
        const v = try self.expect(Kind.Symbol);
        _ = try self.expect(Kind.LambdaDot);
        const expr = try self.parse();
        var tmp = allocator.create(Expression) catch {
            return ParserError.MemoryFailure;
        };
        tmp.* = .{ .lambda = Lambda{
            .boundVar = v.chars,
            .body = expr,
        } };
        return tmp;
    }

    pub fn parse(self: *Self) ParserError!*Expression {
        if (self.currentToken()) |token| {
            switch (token.kind) {
                .Symbol => {
                    return self.parseVariable();
                },
                .LambdaBegin => {
                    return self.parseLambda();
                },
                .ApplicationOpen => {
                    return self.parseApplication();
                },
                else => return ParserError.UnexpectedToken,
            }

            return ParserError.NotImplemented;
        } else {
            return ParserError.EndOfFile;
        }
    }

    pub fn freeExpr(self: *Self, expr: *Expression) void {
        switch (expr.*) {
            .variable => {
                allocator.destroy(expr);
            },
            .application => |*app| {
                self.freeExpr(app.left);
                self.freeExpr(app.right);
                allocator.destroy(app);
            },
            .lambda => |*lam| {
                self.freeExpr(lam.body);
                allocator.destroy(lam);
            },
        }
    }
};

fn printExpr(out: anytype, expr: *Expression) !void {
    switch (expr.*) {
        .variable => |v| {
            _ = try out.write(v.name);
        },
        .application => |app| {
            _ = try out.write("(");
            try printExpr(out, app.left);
            _ = try out.write(" ");
            try printExpr(out, app.right);
            _ = try out.write(")");
        },
        .lambda => |l| {
            _ = try out.write("\\");
            _ = try out.write(l.boundVar);
            _ = try out.write(". ");
            try printExpr(out, l.body);
        },
    }
}

fn collectArgs(args: *std.ArrayList([]const u8)) !void {
    var args_iter = try std.process.argsWithAllocator(args.allocator);
    while (args_iter.next()) |arg| {
        try args.append(arg);
    }
}

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var args = std.ArrayList([]const u8).init(allocator);
    var tokens = std.ArrayList(lexer.Token).init(allocator);
    defer args.deinit();
    defer tokens.deinit();

    try collectArgs(&args);
    var cwd = std.fs.cwd();

    for (args.items[1..]) |arg| {
        cwd.access(arg, std.fs.File.OpenFlags{ .mode = .read_only }) catch |err| {
            try stdout.print("ERROR: {s}: {!}\n", .{ arg, err });
            continue;
        };

        // TODO: may need to change the limit to load a bigger file
        const content = try cwd.readFileAlloc(allocator, arg, 1024 * 1024);
        var lexa = lexer.Lexer.init(content);
        lexa.allTokens(&tokens) catch |err| {
            try stdout.print("ERROR: {!}\n", .{err});
            continue;
        };

        var parser = Parser.init(tokens.items, allocator);

        while (parser.parse()) |expr| {
            try printExpr(stdout, expr);
            _ = try stdout.write("\n");
            parser.freeExpr(expr);
        } else |err| {
            try stdout.print("ERROR: {!}\n", .{err});
            switch (err) {
                error.UnexpectedToken => {
                    const token = parser.currentToken().?;
                    try stdout.print("    token: chars '{s}', kind: {}\n", .{ token.chars, token.kind });
                },
                else => {},
            }
        }
    }
    try bw.flush(); // don't forget to flush!
}
