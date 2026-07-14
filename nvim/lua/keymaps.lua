local keymap = vim.keymap
local opts = {
    noremap = true,
    silent = true,
}

-- Clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Alt+Backspace: delete previous word
vim.keymap.set(
    'i',
    '<A-BS>',
    '<C-w>',
    { desc = 'Clear Word [ctrl + w]', noremap = true, silent = true }
)

-- Split windows
vim.keymap.set('n', 'sv', ':vsplit<Return>', { desc = 'Vertical Split' })
vim.keymap.set('n', 'shh', ':split<Return>', { desc = 'Horizontal Split' })

-- Window navigation
vim.keymap.set('n', '<leader>wh', '<C-w>h', { desc = 'Focus Window left' })
vim.keymap.set('n', '<leader>wj', '<C-w>j', { desc = 'Focus Window down' })
vim.keymap.set('n', '<leader>wk', '<C-w>k', { desc = 'Focus Window up' })
vim.keymap.set('n', '<leader>wl', '<C-w>l', { desc = 'Focus Window right' })

-- Arrow keys version
vim.keymap.set('n', '<leader>w<Left>', '<C-w>h', { desc = 'Focus Window left' })
vim.keymap.set('n', '<leader>w<Down>', '<C-w>j', { desc = 'Focus Window down' })
vim.keymap.set('n', '<leader>w<Up>', '<C-w>k', { desc = 'Focus Window up' })
vim.keymap.set(
    'n',
    '<leader>w<Right>',
    '<C-w>l',
    { desc = 'Focus Window right' }
)

-- Tabs
keymap.set('n', 'te', ':tabedit', opts)
keymap.set('n', '<tab>', ':tabnext<Return>', opts)
keymap.set('n', '<s-tab>', ':tabprev<Return>', opts)
keymap.set('n', '<leader><tab>d', ':tabclose<Return>', opts)

-- LSP Rename
vim.keymap.set('n', '<leader>cr', function()
    vim.lsp.buf.rename()
end, {
    expr = true,
    desc = 'LSP Rename',
})

-- Buffer functions
local function delete_other_buffers()
    local current_buf = vim.api.nvim_get_current_buf()
    local buffers = vim.api.nvim_list_bufs()

    for _, buf in ipairs(buffers) do
        if buf ~= current_buf and vim.api.nvim_buf_is_loaded(buf) then
            vim.api.nvim_buf_delete(buf, {})
        end
    end
end

-- Buffers
keymap.set('n', '<S-h>', '<cmd>bprevious<cr>', {
    desc = 'Prev Buffer',
})
keymap.set('n', '<S-l>', '<cmd>bnext<cr>', {
    desc = 'Next Buffer',
})
keymap.set('n', '[b', '<cmd>bprevious<cr>', {
    desc = 'Prev Buffer',
})
keymap.set('n', ']b', '<cmd>bnext<cr>', {
    desc = 'Next Buffer',
})
keymap.set('n', '<leader>bd', '<cmd>bdelete<CR>', {
    desc = 'Delete Buffer',
})
keymap.set('n', '<leader>bo', delete_other_buffers, {
    desc = 'Delete Other Buffers',
})
keymap.set('n', '<leader>bD', '<cmd>:bd<cr>', {
    desc = 'Delete Buffer and Window',
})

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', {
        clear = true,
    }),
    callback = function()
        vim.highlight.on_yank()
    end,
})

-- Better indenting
keymap.set('v', '<', '<gv')
keymap.set('v', '>', '>gv')

-- Custom keymaps
-- Copy Line Down (Shift + Alt + Down)
vim.keymap.set(
    'n',
    '<S-A-Down>',
    'yyp',
    { desc = 'Copy Line Down [Shift + alt + Down]', noremap = true, silent = true }
)

-- Copy Line Up (Shift + Alt + Up)
vim.keymap.set(
    'n',
    '<S-A-Up>',
    'yyP',
    { desc = 'Copy Line UP [Shift + alt + Up]', noremap = true, silent = true }
)

-- Open Folder (Ctrl + O) - using nvim-tree
vim.keymap.set(
    'n',
    '<C-o>',
    '<cmd>NvimTreeToggle<cr>',
    { desc = 'Open Folder [ctrl + o]', noremap = true, silent = true }
)

-- Move Line Up/Down (Alt + Up / Alt + Down)
vim.keymap.set(
    'n',
    '<A-Up>',
    ':m .-2<CR>==',
    { desc = 'Move line up [alt + up]', noremap = true, silent = true }
)
vim.keymap.set(
    'n',
    '<A-Down>',
    ':m .+1<CR>==',
    { desc = 'Move line down [alt + down]', noremap = true, silent = true }
)

-- For visual mode (VS Code behavior)
vim.keymap.set('v', '<A-Up>', ":m '<-2<CR>gv=gv", { noremap = true, silent = true })
vim.keymap.set('v', '<A-Down>', ":m '>+1<CR>gv=gv", { noremap = true, silent = true })

-- For CheatSheat Preview
vim.keymap.set('n', '<leader>ch', function()
    require('util.cheatsheat').open()
end, { desc = 'Cheatsheet Show keymaps' })
