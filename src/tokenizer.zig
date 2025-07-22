const std = @import("std");

const special_chars = [_]u8{
    '*',
    '|',
    '+',
    '-',
    '(',
    ')',
    '[',
    ']',
};

pub const Kind = enum {
    KLEENE_STAR,
    PIPE,
    PLUS,
    MINUS,
    LEFT_PAREN,
    RIGHT_PAREN,
    RIGHT_SQUARED_BRACKET,
    LEFT_SQARED_BRACKET,
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
                '+' => self.tokens.append(Token.create(.PLUS, null)),
                '(' => self.tokens.append(Token.create(.LEFT_PAREN, null)),
                ')' => self.tokens.append(Token.create(.RIGHT_PAREN, null)),
                '[' => self.tokens.append(Token.create(.LEFT_SQARED_BRACKET, null)),
                ']' => self.tokens.append(Token.create(.RIGHT_SQUARED_BRACKET, null)),
                '-' => self.tokens.append(Token.create(.MINUS, null)),
                'a'...'z',
                'A'...'Z',
                '0'...'9',
                => try self.tokens.append(Token.create(.CHAR, c)),
                '\\' => {
                    _ = self.advance();
                    if (!self.isAtEnd()) try self.tokens.append(Token.create(.CHAR, c));
                },
                else => {
                    if (!isSpecialChar(c)) {
                        try self.tokens.append(Token.create(.CHAR, c));
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
        const expected_token = [_]Kind{ .CHAR, .PIPE, .CHAR, .KLEENE_STAR, .CHAR, .EOP };
        const pattern = "a|B*7\\";
        var tokenizer = Tokenizer.init(pattern, allocator);
        defer tokenizer.deinit();

        const tokens = try tokenizer.scanTokens();

        try std.testing.expectEqual(6, tokens.len);
        for (tokens, 0..) |token, i| {
            try std.testing.expectEqual(expected_token[i], token.kind);
        }
    }
}
