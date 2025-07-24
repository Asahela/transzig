const std = @import("std");
const Error = @import("error.zig").Error;
const reportError = @import("error.zig").reportError;

const special_chars = [_]u8{ '*', '|' };

pub const Kind = enum {
    KLEENE_STAR,
    PIPE,
    PLUS,
    MINUS,
    LEFT_PAREN,
    RIGHT_PAREN,
    RIGHT_SQUARED_BRACKET,
    LEFT_SQARED_BRACKET,
    CARET,
    CHAR,
    EOP,
};

pub const Token = struct {
    kind: Kind,
    lexeme: ?u8,

    pub fn create(kind: Kind, lexeme: ?u8) Token {
        return .{
            .kind = kind,
            .lexeme = lexeme,
        };
    }
};

pub const Tokenizer = struct {
    pattern: []const u8,
    tokens: std.ArrayList(Token),
    cursor: usize,

    pub fn init(pattern: []const u8, allocator: std.mem.Allocator) Tokenizer {
        return .{
            .pattern = pattern,
            .tokens = std.ArrayList(Token).init(allocator),
            .cursor = 0,
        };
    }

    pub fn deinit(self: *Tokenizer) void {
        self.tokens.deinit();
    }

    pub fn scanTokens(self: *Tokenizer) ![]const Token {
        while (!self.isAtEnd()) {
            const c = self.peek();

            try switch (c) {
                '*' => self.tokens.append(Token.create(.KLEENE_STAR, null)),
                '|' => self.tokens.append(Token.create(.PIPE, null)),
                'a'...'z',
                'A'...'Z',
                '0'...'9',
                => try self.tokens.append(Token.create(.CHAR, c)),
                '\\' => {
                    self.advance();
                    if (!self.isAtEnd()) {
                        if (std.ascii.isAscii(self.peek())) {
                            try self.tokens.append(Token.create(.CHAR, self.peek()));
                        } else {
                            try reportError("Unexpected symbol.");
                            return Error.ScanError;
                        }
                    }
                },
                else => {
                    if (!isSpecialChar(c) and std.ascii.isAscii(c)) {
                        try self.tokens.append(Token.create(.CHAR, c));
                    } else {
                        try reportError("Unexpected symbol.");
                        return Error.ScanError;
                    }
                },
            };

            self.advance();
        }

        try self.tokens.append(Token.create(.EOP, null));
        return self.tokens.items;
    }

    fn isAtEnd(self: *Tokenizer) bool {
        return self.pattern.len <= self.cursor;
    }

    fn advance(self: *Tokenizer) void {
        self.cursor += 1;
    }

    fn peek(self: *Tokenizer) u8 {
        if (self.isAtEnd()) return 0;
        return self.pattern[self.cursor];
    }

    fn isSpecialChar(c: u8) bool {
        for (special_chars) |sc| {
            if (c == sc) return true;
        }
        return false;
    }
};

test "scanTokens" {
    const allocator = std.testing.allocator;

    {
        const pattern = "";
        var tokenizer = Tokenizer.init(pattern, allocator);
        defer tokenizer.deinit();

        const tokens = try tokenizer.scanTokens();

        try std.testing.expectEqual(1, tokens.len);
        try std.testing.expectEqual(Kind.EOP, tokens[0].kind);
    }

    {
        const expected_token = [_]Kind{ .CHAR, .EOP };
        const pattern = "\\\\";
        var tokenizer = Tokenizer.init(pattern, allocator);
        defer tokenizer.deinit();

        const tokens = try tokenizer.scanTokens();

        try std.testing.expectEqual(2, tokens.len);
        for (tokens, 0..) |token, i| {
            try std.testing.expectEqual(expected_token[i], token.kind);
        }
    }

    {
        const expected_token = [_]Kind{ .CHAR, .EOP };
        const pattern = "\\(";
        var tokenizer = Tokenizer.init(pattern, allocator);
        defer tokenizer.deinit();

        const tokens = try tokenizer.scanTokens();

        try std.testing.expectEqual(2, tokens.len);
        for (tokens, 0..) |token, i| {
            try std.testing.expectEqual(expected_token[i], token.kind);
        }
    }

    {
        const expected_token = [_]Kind{ .CHAR, .PIPE, .CHAR, .KLEENE_STAR, .CHAR, .CHAR, .EOP };
        const pattern = "a|B*7\\(";
        var tokenizer = Tokenizer.init(pattern, allocator);
        defer tokenizer.deinit();

        const tokens = try tokenizer.scanTokens();

        try std.testing.expectEqual(7, tokens.len);
        for (tokens, 0..) |token, i| {
            try std.testing.expectEqual(expected_token[i], token.kind);
        }
    }

    {
        const pattern = "è";
        var tokenizer = Tokenizer.init(pattern, allocator);
        defer tokenizer.deinit();

        try std.testing.expectError(Error.ScanError, tokenizer.scanTokens());
    }

    {
        const pattern = "7\\è";
        var tokenizer = Tokenizer.init(pattern, allocator);
        defer tokenizer.deinit();

        try std.testing.expectError(Error.ScanError, tokenizer.scanTokens());
    }
}
