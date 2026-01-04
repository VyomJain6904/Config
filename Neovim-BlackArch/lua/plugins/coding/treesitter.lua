return {
    {
        "nvim-treesitter/nvim-treesitter",
        event = { "BufReadPost", "BufNewFile" },
        build = ":TSUpdate",
        config = function()
            local ok, configs = pcall(require, "nvim-treesitter.configs")
            if not ok then
                return
            end

            configs.setup({
                ensure_installed = {
                    "c",
                    "go",
                    "zig",
                    "gomod",
                    "gosum",
                    "json",
                    "python",
                    "vim",
                    "vimdoc",
                    "ninja",
                    "rst",
                    "rust",
                    "toml",
                    "ron",
                    "markdown",
                    "markdown_inline",
                },

                highlight = {
                    enable = true,
                },

                indent = {
                    enable = true,
                },

                auto_install = true,
            })

            -- Custom filetype mapping
            vim.filetype.add({
                pattern = {
                    ["config"] = "dosini",
                },
            })
        end,
    },
}
