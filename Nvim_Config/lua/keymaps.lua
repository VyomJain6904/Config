local keymap = vim.keymap
local opts = {
    noremap = true,
    silent = true,
}

-- Clear highlights on search when pressing <Esc> in normal mode
keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Alt+Backspace: delete previous word
keymap.set('i', '<A-BS>', '<C-w>', { noremap = true })

-- Split windows
keymap.set('n', 'sh', ':vsplit<Return>', opts)
keymap.set('n', 'sv', ':split<Return>', opts)

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
keymap.set('n', '<S-A-Down>', 'yyp', opts)

-- Copy Line Up (Shift + Alt + Up)
keymap.set('n', '<S-A-Up>', 'yyP', opts)

-- Open Folder (Ctrl + O)
-- Equivalent: open file browser in Neovim
keymap.set('n', '<C-o>', ':Oil<CR>', opts) -- If using oil.nvim
-- OR if using netrw
-- keymap.set("n", "<C-o>", ":Ex<CR>", opts)

-- Multiple cursors (Ctrl+Shift+Up / Ctrl+Shift+Down)
-- Using vim-visual-multi plugin
keymap.set('n', '<C-S-Up>', '<Plug>(VM-Add-Cursor-Up)', {})
keymap.set('n', '<C-S-Down>', '<Plug>(VM-Add-Cursor-Down)', {})

-- Move Line Up/Down (Alt + Up / Alt + Down)
keymap.set('n', '<A-Up>', ':m .-2<CR>==', opts)
keymap.set('n', '<A-Down>', ':m .+1<CR>==', opts)

-- For visual mode (VS Code behavior)
keymap.set('v', '<A-Up>', ":m '<-2<CR>gv=gv", opts)
keymap.set('v', '<A-Down>', ":m '>+1<CR>gv=gv", opts)

-- For CheatSheat Preview
vim.keymap.set('n', '<leader>ch', function()
    require('util.cheatsheat').open()
end, { desc = 'Cheatsheet Show keymaps' })
