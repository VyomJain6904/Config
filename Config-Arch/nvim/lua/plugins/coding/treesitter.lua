return {
    {
        'nvim-treesitter/nvim-treesitter',
        build = ':TSUpdate',
        main = 'nvim-treesitter.configs',
        opts = {
            ensure_installed = {
                'astro',
                'bash',
                'blade',
                'c',
                'caddy',
                'css',
                'diff',
                'dockerfile',
                'editorconfig',
                'gitignore',
                'go',
                'zig',
                'gomod',
                'gosum',
                'html',
                'javascript',
                'json',
                'lua',
                'luadoc',
                'python',
                'sql',
                'typescript',
                'vim',
                'vimdoc',
                'ninja',
                'rst',
                'rust',
                'toml',
                'ron',
                'markdown',
                'markdown_inline',
            },

            auto_install = true,
        },

        config = function()
            vim.filetype.add {
                pattern = {
                    ['config'] = 'dosini',
                },
            }
        end,
    },
}
