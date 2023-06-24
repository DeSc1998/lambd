const std = @import("std");

pub const LexerError = error{
    EndOfFile,
    NotImplemented,
    MemoryFailure,
    UnknownError,
};

pub const TokenKind = enum {
    Symbol,
    EqualOperator,
    LambdaBegin,
    LambdaDot,
    ApplicationOpen,
    ApplicationClose,
    Unknown,
};

pub const Token = struct {
    chars: []const u8,
    kind: TokenKind,
};

pub const Lexer = struct {
    data: []const u8,
    current_position: u64,

    const Self = @This();

    pub fn init(input: []const u8) Self {
        return .{
            .data = input,
            .current_position = 0,
        };
    }

    pub fn reset(self: *Self) void {
        self.current_position = 0;
    }

    fn anyOf(char: u8, chars: []const u8) bool {
        for (chars) |c| {
            if (c == char) {
                return true;
            }
        }
        return false;
    }

    fn isSymbolChar(c: u8) bool {
        const char = std.ascii;
        return !char.isControl(c) and !char.isWhitespace(c) and !anyOf(c, "().\\");
    }

    fn lexSymbol(self: *Self) LexerError!Token {
        const pos = self.current_position;
        while (self.readChar()) |char| {
            if (!isSymbolChar(char)) {
                self.current_position -= 1;
                return .{
                    .chars = self.data[pos..self.current_position],
                    .kind = TokenKind.Symbol,
                };
            }
        } else |err| {
            return err;
        }
    }

    fn countNewlines(self: Self) u64 {
        var count: u64 = 0;
        for (0.., self.data) |idx, char| {
            if (idx >= self.current_position) {
                return count;
            }

            if (char == '\n') {
                count += 1;
            }
        }
        return count;
    }

    fn skipOne(self: *Self) LexerError!void {
        _ = try self.readChar();
    }

    fn skipWhitespce(self: *Self) LexerError!void {
        // zig fmt: off
        while (
            self.current_position < self.data.len
                and std.ascii.isWhitespace(self.data[self.current_position])
                ) : (self.current_position += 1) {
            if (self.current_position + 1 >= self.data.len) {
                return LexerError.EndOfFile;
            }
        }
        // zig fmt: on
    }

    fn readChar(self: *Self) LexerError!u8 {
        if (self.data.len > self.current_position) {
            const c = self.data[self.current_position];
            self.current_position += 1;
            return c;
        } else {
            return LexerError.EndOfFile;
        }
    }

    // untyped lambda-calculus
    // Def: Term ::= A | (Term Term) | \A. Term
    // A ::= `any character sequance excluding escaped chars, whitespaces and any of '().\'`

    fn nextToken(self: *Self) LexerError!Token {
        self.skipWhitespce() catch |err| {
            if (err != LexerError.EndOfFile) {
                return LexerError.UnknownError;
            }
        };
        const position = self.current_position;
        const char = self.readChar() catch |err| {
            return err;
        };
        if (char == '\\') {
            return .{
                .chars = self.data[position..self.current_position],
                .kind = TokenKind.LambdaBegin,
            };
        } else if (char == '.') {
            return .{
                .chars = self.data[position..self.current_position],
                .kind = TokenKind.LambdaDot,
            };
        } else if (char == '(') {
            return .{
                .chars = self.data[position..self.current_position],
                .kind = TokenKind.ApplicationOpen,
            };
        } else if (char == ')') {
            return .{
                .chars = self.data[position..self.current_position],
                .kind = TokenKind.ApplicationClose,
            };
        } else if (isSymbolChar(char)) {
            self.current_position -= 1;
            return self.lexSymbol();
        } else {
            const s = self.data[position..self.current_position];
            return .{
                .chars = s,
                .kind = TokenKind.Unknown,
            };
        }

        return LexerError.NotImplemented;
    }

    pub fn allTokens(self: *Self, tokens: *std.ArrayList(Token)) LexerError!void {
        while (self.nextToken()) |token| {
            tokens.append(token) catch {
                return LexerError.MemoryFailure;
            };
        } else |err| {
            if (err != LexerError.EndOfFile) {
                return err;
            }
        }
    }
};
