return {
    'lukas-reineke/indent-blankline.nvim',
    main = 'ibl',
    event = 'BufReadPre',
    opts = {
        indent = {
            char = '▏',
            highlight = 'IblIndent',
        },
        scope = {
            enabled = true,
            highlight = 'IblScope',
            show_start = false,
            show_end = false,
        },
    },
}
