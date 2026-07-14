return {{
    'mason.nvim',
    opts = {
        ensure_installed = {'hadolint'}
    }
}, {
    'neovim/nvim-lspconfig',
    opts = {
        servers = {
            dockerls = {},
            docker_compose_language_service = {}
        }
    }
}}
