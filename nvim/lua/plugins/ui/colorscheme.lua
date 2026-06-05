local transparent_groups = {
  'Normal',
  'NormalNC',
  'NormalFloat',
  'SignColumn',
  'LineNr',
  'CursorLine',
  'CursorLineNr',
  'EndOfBuffer',
  'WinSeparator',
  'VertSplit',
  'FoldColumn',
  'StatusLine',
  'StatusLineNC',
  'WinBar',
  'WinBarNC',
  'TabLine',
  'TabLineFill',
  'TabLineSel',
  'Pmenu',
  'PmenuSel',
  'PmenuSbar',
  'PmenuThumb',
  'FloatBorder',
  'FloatTitle',
  'DiagnosticVirtualTextError',
  'DiagnosticVirtualTextWarn',
  'DiagnosticVirtualTextInfo',
  'DiagnosticVirtualTextHint',
  'ColorColumn',
  'CursorColumn',
  'NeoTreeNormal',
  'NeoTreeNormalNC',
  'NeoTreeEndOfBuffer',
  'TelescopeNormal',
  'TelescopeBorder',
  'TelescopePromptNormal',
  'TelescopePromptBorder',
  'TelescopePromptTitle',
  'TelescopeResultsNormal',
  'TelescopeResultsBorder',
  'TelescopePreviewNormal',
  'TelescopePreviewBorder',
  'MasonNormal',
  'LspInfoBorder',
  'DiagnosticFloatingError',
  'DiagnosticFloatingWarn',
  'DiagnosticFloatingInfo',
  'DiagnosticFloatingHint',
  'IblIndent',
}

local function set_transparent()
  for _, group in ipairs(transparent_groups) do
    vim.api.nvim_set_hl(0, group, { bg = 'NONE' })
  end
  vim.api.nvim_set_hl(0, 'IblScope', { fg = '#888888', bold = true })
end

vim.o.background = 'dark'
vim.o.winblend = 10
vim.o.pumblend = 10
vim.cmd.colorscheme('default')
set_transparent()

vim.api.nvim_create_autocmd('ColorScheme', {
  pattern = '*',
  callback = set_transparent,
})

return {}
