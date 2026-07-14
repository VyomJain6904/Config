-- LSP Plugins
return {
    {
        -- Lua dev
        'folke/lazydev.nvim',
        ft = 'lua',
        opts = {
            library = {
                {
                    path = '${3rd}/luv/library',
                    words = { 'vim%.uv' },
                },
            },
        },
    },
    {
        -- Main LSP configuration
        'neovim/nvim-lspconfig',
        dependencies = {
            {
                'williamboman/mason.nvim',
                opts = {
                    PATH = 'append',
                },
            },
            'williamboman/mason-lspconfig.nvim',
            'WhoIsSethDaniel/mason-tool-installer.nvim',
            'hrsh7th/cmp-nvim-lsp',
        },

        opts = {
            servers = {
                rust_analyzer = {
                    settings = {
                        ['rust-analyzer'] = {
                            cargo = {
                                allFeatures = true,
                            },
                            checkOnSave = {
                                command = 'clippy',
                            },
                        },
                    },
                },
                gopls = {
                    settings = {
                        gopls = {
                            analyses = {
                                unusedparams = true,
                            },
                            staticcheck = true,
                        },
                    },
                },
                vtsls = {
                    settings = {
                        complete_function_calls = true,
                        typescript = {
                            preferences = {
                                importModuleSpecifier = 'non-relative',
                            },
                        },
                    },
                },
                lua_ls = {
                    settings = {
                        Lua = {
                            completion = {
                                callSnippet = 'Replace',
                            },
                            diagnostics = {
                                globals = { 'vim' },
                            },
                        },
                    },
                },
                clangd = {
                    cmd = {
                        'clangd',
                        '--background-index',
                        '--clang-tidy',
                        '--completion-style=detailed',
                    },
                },
                bashls = {},
                astro = {},
                cssls = {},
                pyright = {},
                eslint = {
                    settings = {
                        workingDirectory = {
                            mode = 'auto',
                        },
                    },
                },
                zls = {
                    settings = {
                        zls = {
                            enable_autofix = true,
                            warn_style = true,
                        },
                    },
                },
            },
        },
        config = function(_, opts)
            vim.api.nvim_create_autocmd('LspAttach', {
                group = vim.api.nvim_create_augroup('kickstart-lsp-attach', {
                    clear = true,
                }),
                callback = function(event)
                    local map = function(keys, func, desc, mode)
                        mode = mode or 'n'
                        vim.keymap.set(mode, keys, func, {
                            buffer = event.buf,
                            desc = desc,
                        })
                    end

                    local client =
                        vim.lsp.get_client_by_id(event.data.client_id)

                    if
                        client
                        and client.supports_method(
                            vim.lsp.protocol.Methods.textDocument_codeAction
                        )
                    then
                        map(
                            '<leader>ca',
                            vim.lsp.buf.code_action,
                            'Code Action',
                            { 'n', 'x' }
                        )
                    end
                    map('gD', vim.lsp.buf.declaration, 'Goto Declaration')

                    if
                        client
                        and client.supports_method(
                            vim.lsp.protocol.Methods.textDocument_documentHighlight
                        )
                    then
                        local highlight_augroup = vim.api.nvim_create_augroup(
                            'kickstart-lsp-highlight',
                            {
                                clear = false,
                            }
                        )
                        vim.api.nvim_create_autocmd(
                            { 'CursorHold', 'CursorHoldI' },
                            {
                                buffer = event.buf,
                                group = highlight_augroup,
                                callback = vim.lsp.buf.document_highlight,
                            }
                        )

                        vim.api.nvim_create_autocmd(
                            { 'CursorMoved', 'CursorMovedI' },
                            {
                                buffer = event.buf,
                                group = highlight_augroup,
                                callback = vim.lsp.buf.clear_references,
                            }
                        )

                        vim.api.nvim_create_autocmd('LspDetach', {
                            group = vim.api.nvim_create_augroup(
                                'kickstart-lsp-detach',
                                {
                                    clear = true,
                                }
                            ),
                            callback = function(ev)
                                vim.lsp.buf.clear_references()
                                vim.api.nvim_clear_autocmds {
                                    group = 'kickstart-lsp-highlight',
                                    buffer = ev.buf,
                                }
                            end,
                        })
                    end

                    if
                        client
                        and client.supports_method(
                            vim.lsp.protocol.Methods.textDocument_inlayHint
                        )
                    then
                        map('<leader>th', function()
                            vim.lsp.inlay_hint.enable(
                                not vim.lsp.inlay_hint.is_enabled {
                                    bufnr = event.buf,
                                }
                            )
                        end, 'Toggle Inlay Hints')
                    end
                end,
            })

            -- LSP capabilities
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            capabilities = vim.tbl_deep_extend(
                'force',
                capabilities,
                require('cmp_nvim_lsp').default_capabilities()
            )
            capabilities.textDocument.foldingRange = {
                dynamicRegistration = false,
                lineFoldingOnly = true,
            }

            -- Merge servers from opts (includes language plugin additions like docker, tailwind, python)
            local servers = vim.tbl_deep_extend('force', opts.servers or {}, {})

            --------------------------------------------------------
            --                MASON INSTALLATION LIST              --
            --------------------------------------------------------
            local ensure_installed = {}
            for server_name, _ in pairs(servers) do
                table.insert(ensure_installed, server_name)
            end

            require('mason-tool-installer').setup {
                ensure_installed = ensure_installed,
            }

            local lspconfig = require('lspconfig')

            -- Skip servers that should not start
            local disabled_servers = { ts_ls = true }

            require('mason-lspconfig').setup {
                ensure_installed = ensure_installed,
                automatic_installation = true,
                handlers = {
                    function(server_name)
                        -- Skip disabled servers
                        if disabled_servers[server_name] then
                            return
                        end
                        -- Skip non-LSP tools (formatters, linters installed via mason.nvim)
                        if not servers[server_name] and not lspconfig[server_name] then
                            return
                        end
                        local server = servers[server_name] or {}
                        server.capabilities = vim.tbl_deep_extend(
                            'force',
                            {},
                            capabilities,
                            server.capabilities or {}
                        )
                        -- Call custom setup handler if defined (from language plugins)
                        if opts.setup and opts.setup[server_name] then
                            local skip = opts.setup[server_name](lspconfig, server)
                            if skip then
                                return
                            end
                        end
                        lspconfig[server_name].setup(server)
                    end,
                },
            }
        end,
    },
}
