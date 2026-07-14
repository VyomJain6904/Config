return {
-- Mason installers
{
    "williamboman/mason.nvim",
    opts = {
        ensure_installed = {
            "prettierd", "prettier",
            "rustfmt",
            "gofmt", "goimports",
            "black", "isort",
            "shfmt",
            "clang-format",
            "sql-formatter",
            "stylua"
        }
    }
},
-- None-LS (null-ls) fallback formatters
{
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
        local nls = require("null-ls")

        opts.sources = opts.sources or {}

        local add = function(src)
            table.insert(opts.sources, src)
        end

        add(nls.builtins.formatting.prettierd)
        add(nls.builtins.formatting.prettier)
        add(nls.builtins.formatting.rustfmt)
        add(nls.builtins.formatting.goimports)
        add(nls.builtins.formatting.gofmt)
        add(nls.builtins.formatting.black)
        add(nls.builtins.formatting.isort)
        add(nls.builtins.formatting.shfmt)
        add(nls.builtins.formatting.clang_format)
        add(nls.builtins.formatting.stylua)
        add(nls.builtins.formatting.sql_formatter)
    end
}}
