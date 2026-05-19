-- lua/plugins/languages/zig.lua

return {
    {
        'nvim-treesitter/nvim-treesitter',
        opts = function(_, opts)
            opts = opts or {}
            opts.ensure_installed = opts.ensure_installed or {}

            if type(opts.ensure_installed) == 'table' then
                if not vim.tbl_contains(opts.ensure_installed, 'zig') then
                    table.insert(opts.ensure_installed, 'zig')
                end
            end

            return opts
        end,
    },

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
