local palette = {
    bg = '#0d0d0d',
    panel = '#141414',
    element = '#1e1e1e',
    border = '#333333',
    border_active = '#555555',
    border_subtle = '#222222',
    fg = '#d4d4d4',
    accent = '#f4f4f4',
    muted = '#8a8a8a',
    comment = '#707070',
    keyword = '#f4f4f4',
    func = '#e0e0e0',
    variable = '#c6c6c6',
    string = '#b4b4b4',
    number = '#cccccc',
    type = '#eaeaea',
    operator = '#969696',
    punctuation = '#848484',
    selection = '#2e2e2e',
    cursorline = '#171717',
}

local function set(group, opts)
    vim.api.nvim_set_hl(0, group, opts)
end

local function apply_highlights()
    set('Normal', { fg = palette.fg, bg = palette.bg })
    set('NormalNC', { fg = palette.fg, bg = palette.bg })
    set('NormalFloat', { fg = palette.fg, bg = palette.panel })
    set('FloatBorder', { fg = palette.border, bg = palette.panel })
    set('FloatTitle', { fg = palette.accent, bg = palette.panel, bold = true })
    set('Cursor', { fg = palette.bg, bg = palette.accent })
    set('SignColumn', { bg = palette.bg })
    set('EndOfBuffer', { fg = palette.bg, bg = palette.bg })
    set('LineNr', { fg = palette.muted, bg = palette.bg })
    set('CursorLineNr', { fg = palette.fg, bg = palette.cursorline, bold = true })
    set('CursorLine', { bg = palette.cursorline })
    set('CursorColumn', { bg = palette.cursorline })
    set('ColorColumn', { bg = palette.element })
    set('Visual', { bg = palette.selection })
    set('Search', { fg = palette.bg, bg = palette.accent })
    set('IncSearch', { fg = palette.bg, bg = palette.fg, bold = true })
    set('MatchParen', { fg = palette.accent, bg = palette.element, bold = true })
    set('NonText', { fg = palette.punctuation })
    set('Whitespace', { fg = palette.border_subtle })
    set('Comment', { fg = palette.comment, italic = true })
    set('SpecialComment', { fg = palette.comment, italic = true })

    set('Constant', { fg = palette.number })
    set('String', { fg = palette.string })
    set('Character', { fg = palette.string })
    set('Number', { fg = palette.number })
    set('Boolean', { fg = palette.number })
    set('Float', { fg = palette.number })
    set('Identifier', { fg = palette.variable })
    set('Function', { fg = palette.func })
    set('Statement', { fg = palette.keyword, bold = true })
    set('Conditional', { fg = palette.keyword, bold = true })
    set('Repeat', { fg = palette.keyword, bold = true })
    set('Label', { fg = palette.keyword })
    set('Operator', { fg = palette.operator })
    set('Keyword', { fg = palette.keyword, bold = true })
    set('Exception', { fg = palette.keyword, bold = true })
    set('PreProc', { fg = palette.accent })
    set('Include', { fg = palette.accent })
    set('Define', { fg = palette.accent })
    set('Macro', { fg = palette.accent })
    set('PreCondit', { fg = palette.accent })
    set('Type', { fg = palette.type })
    set('StorageClass', { fg = palette.type })
    set('Structure', { fg = palette.type })
    set('Typedef', { fg = palette.type })
    set('Special', { fg = palette.fg })
    set('SpecialChar', { fg = palette.fg })
    set('Tag', { fg = palette.func })
    set('Delimiter', { fg = palette.punctuation })
    set('SpecialKey', { fg = palette.punctuation })
    set('Title', { fg = palette.accent, bold = true })
    set('Directory', { fg = palette.func })
    set('Error', { fg = palette.accent, bg = palette.element, bold = true })
    set('WarningMsg', { fg = palette.fg, bold = true })
    set('ErrorMsg', { fg = palette.fg, bg = palette.element, bold = true })
    set('MoreMsg', { fg = palette.fg })
    set('Question', { fg = palette.fg })
    set('Todo', { fg = palette.accent, bg = palette.element, bold = true })

    set('Pmenu', { fg = palette.fg, bg = palette.panel })
    set('PmenuSel', { fg = palette.fg, bg = palette.selection, bold = true })
    set('PmenuMatch', { fg = palette.accent, bg = palette.panel, bold = true })
    set('PmenuMatchSel', { fg = palette.accent, bg = palette.selection, bold = true })
    set('PmenuSbar', { bg = palette.element })
    set('PmenuThumb', { bg = palette.border_active })

    set('StatusLine', { fg = palette.fg, bg = palette.panel })
    set('StatusLineNC', { fg = palette.muted, bg = palette.panel })
    set('WinBar', { fg = palette.fg, bg = palette.bg })
    set('WinBarNC', { fg = palette.muted, bg = palette.bg })
    set('WinSeparator', { fg = palette.border, bg = palette.bg })
    set('VertSplit', { fg = palette.border, bg = palette.bg })
    set('TabLine', { fg = palette.fg, bg = palette.element })
    set('TabLineFill', { bg = palette.border_subtle })
    set('TabLineSel', { fg = palette.accent, bg = palette.bg, bold = true })

    set('TelescopeNormal', { fg = palette.fg, bg = palette.panel })
    set('TelescopeBorder', { fg = palette.border, bg = palette.panel })
    set('TelescopePromptNormal', { fg = palette.fg, bg = palette.element })
    set('TelescopePromptBorder', { fg = palette.border, bg = palette.element })
    set('TelescopePromptTitle', { fg = palette.accent, bg = palette.element, bold = true })
    set('TelescopeResultsNormal', { fg = palette.fg, bg = palette.panel })
    set('TelescopeResultsBorder', { fg = palette.border, bg = palette.panel })
    set('TelescopePreviewNormal', { fg = palette.fg, bg = palette.panel })
    set('TelescopePreviewBorder', { fg = palette.border, bg = palette.panel })
    set('TelescopeSelection', { bg = palette.selection, bold = true })
    set('TelescopeMatching', { fg = palette.accent, bold = true })

    set('NeoTreeNormal', { fg = palette.fg, bg = palette.panel })
    set('NeoTreeNormalNC', { fg = palette.fg, bg = palette.panel })
    set('NeoTreeEndOfBuffer', { fg = palette.panel, bg = palette.panel })
    set('NeoTreeWinSeparator', { fg = palette.border, bg = palette.panel })

    set('MasonNormal', { fg = palette.fg, bg = palette.panel })
    set('LspInfoBorder', { fg = palette.border, bg = palette.panel })
    set('DiagnosticFloatingError', { fg = palette.muted, bg = palette.panel })
    set('DiagnosticFloatingWarn', { fg = palette.number, bg = palette.panel })
    set('DiagnosticFloatingInfo', { fg = palette.variable, bg = palette.panel })
    set('DiagnosticFloatingHint', { fg = palette.comment, bg = palette.panel })

    set('DiagnosticError', { fg = palette.muted })
    set('DiagnosticWarn', { fg = palette.number })
    set('DiagnosticInfo', { fg = palette.variable })
    set('DiagnosticHint', { fg = palette.comment })
    set('DiagnosticVirtualTextError', { fg = palette.muted, bg = palette.bg })
    set('DiagnosticVirtualTextWarn', { fg = palette.number, bg = palette.bg })
    set('DiagnosticVirtualTextInfo', { fg = palette.variable, bg = palette.bg })
    set('DiagnosticVirtualTextHint', { fg = palette.comment, bg = palette.bg })
    set('DiagnosticUnderlineError', { undercurl = true, sp = palette.muted })
    set('DiagnosticUnderlineWarn', { undercurl = true, sp = palette.number })
    set('DiagnosticUnderlineInfo', { undercurl = true, sp = palette.variable })
    set('DiagnosticUnderlineHint', { undercurl = true, sp = palette.comment })
    set('DiffAdd', { fg = palette.fg, bg = palette.element })
    set('DiffChange', { fg = palette.number, bg = palette.panel })
    set('DiffDelete', { fg = palette.muted, bg = palette.panel })
    set('DiffText', { fg = palette.accent, bg = palette.selection, bold = true })
    set('IblScope', { fg = palette.border_active, bold = true })

    set('@comment', { link = 'Comment' })
    set('@comment.documentation', { link = 'Comment' })
    set('@keyword', { link = 'Keyword' })
    set('@keyword.function', { link = 'Keyword' })
    set('@keyword.return', { link = 'Keyword' })
    set('@conditional', { link = 'Conditional' })
    set('@repeat', { link = 'Repeat' })
    set('@function', { link = 'Function' })
    set('@function.call', { link = 'Function' })
    set('@function.method', { link = 'Function' })
    set('@function.method.call', { link = 'Function' })
    set('@constructor', { link = 'Function' })
    set('@variable', { link = 'Identifier' })
    set('@variable.member', { link = 'Identifier' })
    set('@property', { fg = palette.variable })
    set('@parameter', { fg = palette.variable })
    set('@string', { link = 'String' })
    set('@string.escape', { fg = palette.punctuation })
    set('@character', { link = 'Character' })
    set('@number', { link = 'Number' })
    set('@boolean', { link = 'Boolean' })
    set('@constant', { link = 'Constant' })
    set('@constant.builtin', { fg = palette.number })
    set('@type', { link = 'Type' })
    set('@type.builtin', { fg = palette.type })
    set('@module', { fg = palette.type })
    set('@operator', { link = 'Operator' })
    set('@punctuation', { fg = palette.punctuation })
    set('@punctuation.delimiter', { fg = palette.punctuation })
    set('@punctuation.bracket', { fg = palette.punctuation })
    set('@tag', { fg = palette.func })
    set('@tag.attribute', { fg = palette.variable })
    set('@tag.delimiter', { fg = palette.punctuation })
    set('@markup.heading', { fg = palette.accent, bold = true })
    set('@markup.link', { fg = palette.variable, underline = true })
    set('@markup.raw', { fg = palette.string })
end

vim.o.background = 'dark'
vim.cmd.colorscheme('default')
apply_highlights()

vim.api.nvim_create_autocmd('ColorScheme', {
    pattern = '*',
    callback = apply_highlights,
})

return {}
