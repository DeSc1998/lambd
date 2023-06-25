const std = @import("std");
const lexer = @import("lexer.zig");
const expr = @import("expr.zig");

const pError = error{
    UnexpectedToken,
};

pub const ParserError = lexer.LexerError || pError;

// untyped lambda-calculus
// Def: Term ::= A | (Term Term) | \A. Term

pub const Parser = struct {
    current_position: u64,
    tokens: []const lexer.Token,
    allocator: std.mem.Allocator,
    // TODO: `Parser` currently relies on 'big' capacity of `exprs`
    //      In `Expression` we may want to use relative pointers
    exprs: std.ArrayList(expr.Expression),

    const Kind = lexer.TokenKind;
    const App = expr.AppExpr(expr.Expression);
    const Lambda = expr.LambdaExpr(expr.Expression);
    const Self = @This();

    pub fn init(tokens: []const lexer.Token, alloc: std.mem.Allocator) Self {
        return Self{
            .current_position = 0,
            .tokens = tokens,
            .allocator = alloc,
            .exprs = std.ArrayList(expr.Expression).init(alloc),
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

    fn parseVariable(self: *Self) ParserError!*expr.Expression {
        const t = try self.expect(Kind.Symbol); // TODO: `Token` needs more metadata for better error reporting
        var tmp: *expr.Expression = self.exprs.addOne() catch {
            return ParserError.MemoryFailure;
        };
        tmp.* = .{ .variable = expr.VarExpr{
            .name = t.chars,
        } };
        return tmp;
    }

    fn parseApplication(self: *Self) ParserError!*expr.Expression {
        _ = try self.expect(Kind.ApplicationOpen);
        const left = try self.parse();
        const right = try self.parse();
        _ = try self.expect(Kind.ApplicationClose);
        var tmp: *expr.Expression = self.exprs.addOne() catch {
            return ParserError.MemoryFailure;
        };
        tmp.* = .{ .application = App{
            .left = left,
            .right = right,
        } };
        return tmp;
    }

    fn parseLambda(self: *Self) ParserError!*expr.Expression {
        _ = try self.expect(Kind.LambdaBegin);
        const v = try self.expect(Kind.Symbol);
        _ = try self.expect(Kind.LambdaDot);
        const e = try self.parse();
        var tmp: *expr.Expression = self.exprs.addOne() catch {
            return ParserError.MemoryFailure;
        };
        tmp.* = .{ .lambda = Lambda{
            .boundVar = v.chars,
            .body = e,
        } };
        return tmp;
    }

    pub fn parse(self: *Self) ParserError!*expr.Expression {
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

    pub fn dumpExprs(self: *Self) []const expr.Expression {
        return self.exprs.items;
    }

    pub fn deinit(self: *Self) void {
        self.exprs.deinit();
    }
};
