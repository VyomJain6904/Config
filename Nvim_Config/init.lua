vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.g.have_nerd_font = true

require 'globals'
require 'options'
require 'keymaps'
require 'lazy-init'

vim.api.nvim_create_autocmd('User', {
    pattern = 'VeryLazy',
    callback = function()
        -- General Editor Transparent Background
        vim.cmd [[
            hi Normal guibg=none ctermbg=none
            hi NormalNC guibg=none ctermbg=none
            hi NormalFloat guibg=none ctermbg=none
            hi FloatBorder guibg=none ctermbg=none
            hi SignColumn guibg=none ctermbg=none
            hi LineNr guibg=none ctermbg=none
            hi EndOfBuffer guibg=none ctermbg=none

            " NeoTree
            hi NeoTreeNormal guibg=none ctermbg=none
            hi NeoTreeNormalNC guibg=none ctermbg=none
            hi NeoTreeEndOfBuffer guibg=none ctermbg=none
            hi NeoTreeWinSeparator guibg=none ctermbg=none

            " Telescope
            hi TelescopeNormal guibg=none ctermbg=none
            hi TelescopeBorder guibg=none ctermbg=none
            hi TelescopePromptNormal guibg=none ctermbg=none
            hi TelescopePromptBorder guibg=none ctermbg=none
            hi TelescopeResultsNormal guibg=none ctermbg=none
            hi TelescopeResultsBorder guibg=none ctermbg=none
            hi TelescopePreviewNormal guibg=none ctermbg=none
            hi TelescopePreviewBorder guibg=none ctermbg=none

            " Mason + LSP Float Windows
            hi MasonNormal guibg=none ctermbg=none
            hi Pmenu guibg=none ctermbg=none
            hi LspInfoBorder guibg=none ctermbg=none
            hi DiagnosticFloatBg guibg=none ctermbg=none
        ]]
    end,
})
