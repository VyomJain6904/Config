return {{
    'mfussenegger/nvim-lint',
    event = {'BufReadPre', 'BufNewFile'},
    config = function()
        local lint = require 'lint'

        -- Remove all PHP / Laravel linters
        lint.linters = lint.linters or {}
        lint.linters_by_ft = lint.linters_by_ft or {}

        local function has_file(files)
            for _, file in ipairs(files) do
                if vim.fn.filereadable(vim.fn.getcwd() .. '/' .. file) == 1 then
                    return true
                end
            end
            return false
        end

        -- JS linting handled by ESLint LSP, so no linters added here

        local lint_augroup = vim.api.nvim_create_augroup('lint', {
            clear = true
        })
        vim.api.nvim_create_autocmd({'BufEnter', 'BufWritePost', 'InsertLeave'}, {
            group = lint_augroup,
            callback = function()
                if not vim.opt_local.modifiable:get() then
                    return
                end

                -- No linters defined — ESLint LSP will handle JS/TS
                lint.try_lint(nil, {
                    ignore_errors = true
                })
            end
        })
    end
}}
