-- Full unified formatter setup (Prettier, Rustfmt, Black, Go, C/C++, Bash etc.)
local prettier_ft = {'css', 'graphql', 'html', 'javascript', 'javascriptreact', 'json', 'jsonc', 'less', 'scss',
                     'typescript', 'typescriptreact', 'vue', 'yaml', 'markdown', 'astro', 'svelte'}

return { ---------------------------------------------------------------------------
-- Mason installers
---------------------------------------------------------------------------
{
    "williamboman/mason.nvim",
    opts = {
        ensure_installed = { -- Prettier stack
        "prettierd", "prettier", -- Rust
        "rustfmt", -- Go
        "gofmt", "goimports", -- Python
        "black", "isort", -- Bash
        "shfmt", -- C / C++
        "clang-format", -- SQL
        "sql-formatter", -- Lua
        "stylua"}
    }
}, ---------------------------------------------------------------------------
-- Conform.nvim (Main Formatting Engine)
---------------------------------------------------------------------------
{
    "stevearc/conform.nvim",
    opts = function(_, opts)
        opts.formatters_by_ft = opts.formatters_by_ft or {}

        -----------------------------------------------------------------------
        -- Prettier / Prettierd for Web stack
        -----------------------------------------------------------------------
        for _, ft in ipairs(prettier_ft) do
            opts.formatters_by_ft[ft] = {"prettierd", "prettier"}
        end

        -----------------------------------------------------------------------
        -- Rust
        -----------------------------------------------------------------------
        opts.formatters_by_ft.rust = {"rustfmt"}

        -----------------------------------------------------------------------
        -- Go
        -----------------------------------------------------------------------
        opts.formatters_by_ft.go = {"goimports", "gofmt"}

        -----------------------------------------------------------------------
        -- Python
        -----------------------------------------------------------------------
        opts.formatters_by_ft.python = {"isort", "black"}

        -----------------------------------------------------------------------
        -- Bash / Shell
        -----------------------------------------------------------------------
        opts.formatters_by_ft.sh = {"shfmt"}
        opts.formatters_by_ft.bash = {"shfmt"}

        -----------------------------------------------------------------------
        -- C / C++
        -----------------------------------------------------------------------
        opts.formatters_by_ft.c = {"clang-format"}
        opts.formatters_by_ft.cpp = {"clang-format"}

        -----------------------------------------------------------------------
        -- Lua
        -----------------------------------------------------------------------
        opts.formatters_by_ft.lua = {"stylua"}

        -----------------------------------------------------------------------
        -- SQL
        -----------------------------------------------------------------------
        opts.formatters_by_ft.sql = {"sql_formatter"}

        -----------------------------------------------------------------------
        -- Fallback JSON / YAML / Markdown (Prettier)
        -----------------------------------------------------------------------
        opts.formatters_by_ft.json = {"prettierd", "prettier"}
        opts.formatters_by_ft.yaml = {"prettierd", "prettier"}
        opts.formatters_by_ft.markdown = {"prettierd", "prettier"}

        -----------------------------------------------------------------------
        -- Auto-format on save
        -----------------------------------------------------------------------
        opts.format_on_save = {
            lsp_fallback = true,
            async = false,
            timeout_ms = 3000
        }
    end
}, ---------------------------------------------------------------------------
-- None-LS (null-ls) fallback formatters
---------------------------------------------------------------------------
{
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
        local nls = require("null-ls")

        opts.sources = opts.sources or {}

        local add = function(src)
            table.insert(opts.sources, src)
        end

        -- Prettier
        add(nls.builtins.formatting.prettierd)
        add(nls.builtins.formatting.prettier)

        -- Rust
        add(nls.builtins.formatting.rustfmt)

        -- Go
        add(nls.builtins.formatting.goimports)
        add(nls.builtins.formatting.gofmt)

        -- Python
        add(nls.builtins.formatting.black)
        add(nls.builtins.formatting.isort)

        -- Bash
        add(nls.builtins.formatting.shfmt)

        -- C/C++
        add(nls.builtins.formatting.clang_format)

        -- Lua
        add(nls.builtins.formatting.stylua)

        -- SQL
        add(nls.builtins.formatting.sql_formatter)
    end
}}
