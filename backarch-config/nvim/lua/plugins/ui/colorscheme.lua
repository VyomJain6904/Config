return {
    'Mofiqul/dracula.nvim',
    lazy = false,
    priority = 1000,
    config = function()
        require('dracula').setup {
            transparent_bg = true,
        }
        vim.cmd 'colorscheme dracula'
        vim.api.nvim_create_autocmd('ColorScheme', {
            pattern = 'dracula',
            callback = function()
                vim.api.nvim_set_hl(0, 'NonText', {
                    fg = '#44475a',
                })
                vim.api.nvim_set_hl(0, 'IblScope', {
                    fg = '#50fa7b',
                    bold = true,
                })
            end,
        })
    end,
}
