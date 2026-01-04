local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
    vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable",
        lazypath })
end
vim.opt.rtp:prepend(vim.env.LAZY or lazypath)

require('lazy').setup({
    spec = {
        'tpope/vim-sleuth',
        {
            import = 'plugins.coding.autopairs',
        },
        {
            import = 'plugins.coding.cmp',
        },
        {
            import = 'plugins.coding.lspconfig',
        },
        {
            import = 'plugins.coding.treesitter',
        },
        {
            import = 'plugins.editor.lualine',
        },
        {
            import = 'plugins.editor.file-tree',
        },
        {
            import = 'plugins.editor.telescope',
        },
        {
            import = 'plugins.editor.which-key',
        },
        {
            import = 'plugins.formatting.conform',
        },
        {
            import = 'plugins.languages.go',
        },
        {
            import = 'plugins.languages.rust',
        },
        {
            import = 'plugins.languages.python',
        },
        {
            import = 'plugins.ui.colorscheme',
        },
        {
            import = 'plugins.ui.dressing',
        },
        {
            import = 'plugins.ui.indent',
        },
        {
            import = 'plugins.ui.treesitter-context',
        },
        {
            import = 'plugins.ui.dashboard',
        },
    },
    defaults = {},
    performance = {
        rtp = {
            disabled_plugins = {
                'gzip',
                'tarPlugin',
                'zipPlugin',
                'netrwPlugin',
                'matchit',
                'matchparen',
                'shada',
                'spellfile',
            },
        },
    },
}, {
    ui = {
        icons = vim.g.have_nerd_font and {} or {
            cmd = '⌘',
            config = '🛠',
            event = '📅',
            ft = '📂',
            init = '⚙',
            keys = '🗝',
            plugin = '🔌',
            runtime = '💻',
            require = '🌙',
            source = '📄',
            start = '🚀',
            task = '📌',
            lazy = '💤 ',
        },
    },
})
