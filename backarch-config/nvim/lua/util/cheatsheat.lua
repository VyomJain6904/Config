local M = {}

local modes = { 'n', 'v', 'i', 'x', 't' }

-- Detect group/plugin
local function detect_group(map)
    local text = ((map.desc or '') .. ' ' .. (map.rhs or '')):lower()
    local lhs = (map.lhs or ''):lower()

    if text:find 'telescope' or lhs:find '<leader>f' then
        return 'Telescope'
    elseif text:find 'lsp' or text:find 'diagnostic' then
        return 'LSP'
    elseif text:find 'dap' or text:find 'debug' then
        return 'DAP'
    elseif text:find 'git' or text:find 'lazygit' then
        return 'Git'
    elseif lhs:find '<leader>b' then
        return 'Buffers'
    elseif lhs:find '<leader>w' or lhs:find '<c%-w>' then
        return 'Windows'
    else
        return 'Misc'
    end
end

-- Collect keymaps
local function collect_keymaps()
    local results = {}

    for _, mode in ipairs(modes) do
        for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
            if m.desc and m.lhs then
                table.insert(results, {
                    mode = mode,
                    lhs = m.lhs,
                    desc = m.desc,
                    group = detect_group(m),
                })
            end
        end
    end

    return results
end

-- Telescope picker
function M.open()
    local ok, pickers = pcall(require, 'telescope.pickers')
    if not ok then
        vim.notify('Telescope not installed', vim.log.levels.ERROR)
        return
    end

    local finders = require 'telescope.finders'
    local conf = require('telescope.config').values
    local actions = require 'telescope.actions'
    local action_state = require 'telescope.actions.state'

    local maps = collect_keymaps()

    pickers
        .new({}, {
            prompt_title = 'Keymaps Cheatsheet',
            finder = finders.new_table {
                results = maps,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = string.format(
                            '[%s] %-12s %-18s %s',
                            entry.group,
                            entry.mode,
                            entry.lhs,
                            entry.desc
                        ),
                        ordinal = entry.group
                            .. ' '
                            .. entry.lhs
                            .. ' '
                            .. entry.desc,
                    }
                end,
            },
            sorter = conf.generic_sorter {},
            attach_mappings = function(prompt_bufnr)
                actions.select_default:replace(function()
                    actions.close(prompt_bufnr)
                    local selection = action_state.get_selected_entry()
                    if selection then
                        vim.notify(
                            string.format(
                                '%s → %s',
                                selection.value.lhs,
                                selection.value.desc
                            ),
                            vim.log.levels.INFO
                        )
                    end
                end)
                return true
            end,
        })
        :find()
end

return M
