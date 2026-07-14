-- lua/plugins/languages/zig.lua

return {
    {
        'L3MON4D3/LuaSnip',
        ft = 'zig',
        config = function()
            local ls = require 'luasnip'
            local s = ls.snippet
            local t = ls.text_node
            local i = ls.insert_node

            ls.add_snippets('zig', {
                s('main', {
                    t {
                        'const std = @import("std");',
                        '',
                        'pub fn main() !void {',
                        '    const stdout = std.io.getStdOut().writer();',
                        '    try stdout.print("',
                    },
                    i(1, 'Hello, Zig!'),
                    t {
                        '\\n", .{});',
                        '}',
                    },
                }),

                s('fn', {
                    t 'fn ',
                    i(1, 'name'),
                    t '(',
                    i(2),
                    t ') ',
                    i(3, 'void'),
                    t { ' {', '    ' },
                    i(0),
                    t { '', '}' },
                }),

                s('test', {
                    t 'test "',
                    i(1, 'name'),
                    t { '" {', '    ' },
                    i(0),
                    t { '', '}' },
                }),
            })
        end,
    },
}
