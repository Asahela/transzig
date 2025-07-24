const std = @import("std");
const ast = @import("ast.zig");
const token = @import("tokenizer.zig");
const Error = @import("error.zig").Error;
const reportError = @import("error.zig").reportError;

const ArenaAllocator = std.heap.ArenaAllocator;

pub const Parser = struct {
    pattern: []const token.Token,
    current: u64,
    arena: std.heap.ArenaAllocator,

    pub fn init(pattern: []const token.Token) Parser {
        return .{
            .pattern = pattern,
            .current = 0,
            .arena = ArenaAllocator.init(std.heap.page_allocator),
        };
    }

    pub fn deinit(self: *Parser) void {
        self.arena.deinit();
    }

    pub fn parse(self: *Parser) !*ast.RegExp {
        if (!self.isAtEnd()) return try self.disjunction();
        try reportError("Unexpected End Of Pattern.");
        return Error.ParseError;
    }

    fn disjunction(self: *Parser) !*ast.RegExp {
        var exp = try self.alternation();

        while (self.match(.PIPE)) {
            const nested_exp = try self.arena.allocator().create(ast.RegExp);
            nested_exp.* = ast.RegExp{
                .disjunction = ast.Disjunction{
                    .left = exp,
                    .right = try self.disjunction(),
                },
            };
            exp = nested_exp;
        }

        return exp;
    }

    fn alternation(self: *Parser) !*ast.RegExp {
        var exp = try self.repetition();

        if (self.peek().kind != token.Kind.PIPE and !self.isAtEnd()) {
            var expressions = std.ArrayList(*const ast.RegExp).init(self.arena.allocator());
            try expressions.append(exp);

            while (self.peek().kind != token.Kind.PIPE and !self.isAtEnd()) {
                exp = try self.repetition();
                try expressions.append(exp);
            }

            const nested_exp = try self.arena.allocator().create(ast.RegExp);
            nested_exp.* = ast.RegExp{ .alternation = ast.Alternation{ .expressions = expressions.items } };
            exp = nested_exp;
        }

        return exp;
    }

    fn repetition(self: *Parser) !*ast.RegExp {
        var exp = try self.char();

        while (self.match(.KLEENE_STAR)) {
            const nested_exp = try self.arena.allocator().create(ast.RegExp);
            nested_exp.* = ast.RegExp{
                .repetition = ast.Repetition{
                    .expression = exp,
                },
            };
            exp = nested_exp;
        }

        return exp;
    }

    fn char(self: *Parser) !*ast.RegExp {
        const char_token = try self.consume(.CHAR);
        const exp = try self.arena.allocator().create(ast.RegExp);
        exp.* = ast.RegExp{ .char = ast.Char{ .value = char_token.lexeme.? } };
        return exp;
    }

    fn match(self: *Parser, token_type: token.Kind) bool {
        if (!self.isAtEnd() and self.peek().kind == token_type) {
            _ = self.advance();
            return true;
        }
        return false;
    }

    fn consume(self: *Parser, token_type: token.Kind) !token.Token {
        if (!self.isAtEnd()) {
            if (token_type == self.peek().kind) {
                return self.advance();
            } else {
                try reportError("Unexpected End Of Pattern");
            }
        }

        try reportError("Unexpected End Of Pattern");
        return Error.ParseError;
    }

    fn advance(self: *Parser) token.Token {
        if (!self.isAtEnd()) self.current += 1;
        return self.pattern[self.current - 1];
    }

    fn peek(self: *Parser) token.Token {
        return self.pattern[self.current];
    }

    fn isAtEnd(self: *Parser) bool {
        if (self.pattern[self.current].kind == token.Kind.EOP) return true else return false;
    }
};

test "parse" {
    const allocator = std.testing.allocator;

    {
        const pattern = "";
        var tokenizer = token.Tokenizer.init(pattern, allocator);
        defer tokenizer.deinit();
        const tokens = try tokenizer.scanTokens();
        var parser = Parser.init(tokens);
        defer parser.deinit();

        try std.testing.expectError(Error.ParseError, parser.parse());
    }

    {
        const pattern = "a";
        var tokenizer = token.Tokenizer.init(pattern, allocator);
        defer tokenizer.deinit();
        const tokens = try tokenizer.scanTokens();
        var parser = Parser.init(tokens);
        defer parser.deinit();

        const parse_tree = try parser.parse();

        try std.testing.expectEqual(ast.Kind.char, @as(ast.Kind, parse_tree.*));
    }

    {
        const pattern = "a*";
        var tokenizer = token.Tokenizer.init(pattern, allocator);
        defer tokenizer.deinit();
        const tokens = try tokenizer.scanTokens();
        var parser = Parser.init(tokens);
        defer parser.deinit();

        const parse_tree = try parser.parse();

        try std.testing.expectEqual(ast.Kind.repetition, @as(ast.Kind, parse_tree.*));
    }

    {
        const pattern = "ab";
        var tokenizer = token.Tokenizer.init(pattern, allocator);
        defer tokenizer.deinit();
        const tokens = try tokenizer.scanTokens();
        var parser = Parser.init(tokens);
        defer parser.deinit();

        const parse_tree = try parser.parse();

        try std.testing.expectEqual(ast.Kind.alternation, @as(ast.Kind, parse_tree.*));
    }

    {
        const pattern = "a|b";
        var tokenizer = token.Tokenizer.init(pattern, allocator);
        defer tokenizer.deinit();
        const tokens = try tokenizer.scanTokens();
        var parser = Parser.init(tokens);
        defer parser.deinit();

        const parse_tree = try parser.parse();

        try std.testing.expectEqual(ast.Kind.disjunction, @as(ast.Kind, parse_tree.*));
    }
}
