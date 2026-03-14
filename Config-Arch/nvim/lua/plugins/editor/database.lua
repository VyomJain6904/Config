return {
    {
        'tpope/vim-dadbod',
        lazy = false,
    },
    {
        'kristijanhusak/vim-dadbod-ui',
        lazy = false,
        dependencies = { 'tpope/vim-dadbod' },
        config = function()
            vim.g.db_ui_use_nerd_fonts = 1
        end,
    },
    {
        'kristijanhusak/vim-dadbod-completion',
        ft = { 'sql', 'mysql', 'plsql' },
    },
    {
        'kkharji/sqlite.lua',
        lazy = true,
    },
}
