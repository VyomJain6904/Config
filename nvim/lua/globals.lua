-- Prevent Netrw from showing up at beginning
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.o.winborder = 'rounded'

vim.diagnostic.config {
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = ' ',
            [vim.diagnostic.severity.WARN] = ' ',
            [vim.diagnostic.severity.INFO] = '󰋼 ',
            [vim.diagnostic.severity.HINT] = ' '
        }
    },
    severity_sort = true
}

-- Prepend mise shims to PATH
vim.env.PATH = vim.env.HOME .. '/.local/share/mise/shims:' .. vim.env.PATH

-- Utility helpers
Utils = {
    lsp = {
        on_attach = function(callback, server_name)
            vim.api.nvim_create_autocmd('LspAttach', {
                callback = function(args)
                    local client = vim.lsp.get_client_by_id(args.data.client_id)
                    if client and client.name == server_name then
                        callback(client, args.buf)
                    end
                end,
            })
        end,
    },
}
