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

return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.o.background = 'dark'
      vim.o.winblend = 10
      vim.o.pumblend = 10

      require("tokyonight").setup({
        style = "night",
        transparent = true,
        styles = {
          sidebars = "transparent",
          floats = "transparent",
        },
      })

      vim.cmd.colorscheme('tokyonight-night')
      set_transparent()

      vim.api.nvim_create_autocmd('ColorScheme', {
        pattern = '*',
        callback = set_transparent,
      })
    end,
  }
}
