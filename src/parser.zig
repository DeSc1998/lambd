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

    const Kind = lexer.TokenKind;
    const Self = @This();

    pub fn init(tokens: []const lexer.Token) Self {
        return Self{
            .current_position = 0,
            .tokens = tokens,
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
            const stdout_file = std.io.getStdOut().writer();
            var bw = std.io.bufferedWriter(stdout_file);
            const out = bw.writer();

            out.print("\nERROR: {}\n", .{ParserError.UnexpectedToken}) catch return ParserError.UnknownError;
            out.print("    expected token of kind {}\n", .{kind}) catch return ParserError.UnknownError;
            const token = self.tokens[self.current_position];
            out.print("    but got {} ('{s}') at {}:{}\n", .{
                token.kind,
                token.chars,
                token.line,
                token.char,
            }) catch return ParserError.UnknownError;
            bw.flush() catch return ParserError.UnknownError;

            return ParserError.UnexpectedToken;
        }
    }

    pub fn currentToken(self: *Self) ?lexer.Token {
        return if (self.current_position < self.tokens.len) self.tokens[self.current_position] else null;
    }

    fn parseVariable(self: *Self) ParserError!usize {
        const t = try self.expect(Kind.Symbol); // TODO: `Token` needs more metadata for better error reporting
        return expr.Expression.addVariable(t.chars) catch {
            return ParserError.MemoryFailure;
        };
    }

    fn parseApplication(self: *Self) ParserError!usize {
        _ = try self.expect(Kind.ApplicationOpen);
        const left = try self.parse();
        const right = try self.parse();
        _ = try self.expect(Kind.ApplicationClose);
        return expr.Expression.addApplication(left, right) catch
            return ParserError.MemoryFailure;
    }

    fn parseLambda(self: *Self) ParserError!usize {
        _ = try self.expect(Kind.LambdaBegin);
        const v = try self.expect(Kind.Symbol);
        _ = try self.expect(Kind.LambdaDot);
        const e = try self.parse();
        return expr.Expression.addLambda(v.chars, e) catch
            return ParserError.MemoryFailure;
    }

    pub fn parse(self: *Self) ParserError!usize {
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
                else => {
                    const stdout_file = std.io.getStdOut().writer();
                    var bw = std.io.bufferedWriter(stdout_file);
                    const out = bw.writer();

                    out.print("\nERROR: {}\n", .{ParserError.UnexpectedToken}) catch return ParserError.UnknownError;
                    out.print("    expected token of kind {}, {} or {}\n", .{ .Symbol, .LambdaBegin, .ApplicationOpen }) catch return ParserError.UnknownError;
                    out.print("    but got {} ('{s}') at {}:{}\n", .{
                        token.kind,
                        token.chars,
                        token.line,
                        token.char,
                    }) catch return ParserError.UnknownError;
                    bw.flush() catch return ParserError.UnknownError;
                    return ParserError.UnexpectedToken;
                },
            }

            return ParserError.NotImplemented;
        } else {
            return ParserError.EndOfFile;
        }
    }
};
