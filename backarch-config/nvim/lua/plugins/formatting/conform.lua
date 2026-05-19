return {{
    "stevearc/conform.nvim",
    opts = function()
        local opts = {
            ---------------------------------------------------------------------
            -- FORMATTERS BY FILETYPE
            ---------------------------------------------------------------------
            formatters_by_ft = {
                -- Core formatters
                lua = {"stylua"},
                blade = {"blade-formatter"},

                -- Prettier stack
                javascript = {"prettierd", "prettier"},
                javascriptreact = {"prettierd", "prettier"},
                typescript = {"prettierd", "prettier"},
                typescriptreact = {"prettierd", "prettier"},
                json = {"prettierd", "prettier"},
                jsonc = {"prettierd", "prettier"},
                css = {"prettierd", "prettier"},
                graphql = {"prettierd", "prettier"},
                handlebars = {"prettierd", "prettier"},
                html = {"prettierd", "prettier"},
                less = {"prettierd", "prettier"},
                scss = {"prettierd", "prettier"},
                vue = {"prettierd", "prettier"},
                yaml = {"prettierd", "prettier"},
                astro = {"prettierd", "prettier"},
                markdown = {"prettierd", "prettier"},

                -- Additional languages
                rust = {"rustfmt"},
                go = {"goimports", "gofmt"},
                python = {"isort", "black"},
                sh = {"shfmt"},
                bash = {"shfmt"},
                c = {"clang-format"},
                cpp = {"clang-format"},
                sql = {"sql-formatter"}
            },

            ---------------------------------------------------------------------
            -- FORMATTER CONFIG (only what's needed)
            ---------------------------------------------------------------------
            formatters = {},

            ---------------------------------------------------------------------
            -- AUTO-FORMAT ON SAVE
            ---------------------------------------------------------------------
            format_after_save = function(bufnr)
                if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
                    return
                end

                local ft = vim.bo[bufnr].filetype

                -------------------------------------------------------------------
                -- PRETTIER FILETYPES
                -------------------------------------------------------------------
                local prettier_supported = {
                    javascript = true,
                    javascriptreact = true,
                    typescript = true,
                    typescriptreact = true,
                    json = true,
                    jsonc = true,
                    css = true,
                    graphql = true,
                    handlebars = true,
                    html = true,
                    less = true,
                    scss = true,
                    vue = true,
                    yaml = true,
                    astro = true,
                    markdown = true
                }

                if prettier_supported[ft] then
                    return {
                        formatters = {"prettierd", "prettier"},
                        timeout_ms = 3000
                    }
                end

                -------------------------------------------------------------------
                -- DEFAULT FALLBACK TO LSP
                -------------------------------------------------------------------
                return {
                    lsp_format = "fallback"
                }
            end
        }

        return opts
    end
}}
