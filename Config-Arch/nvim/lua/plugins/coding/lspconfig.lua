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
                opts = {},
            },
            'williamboman/mason-lspconfig.nvim',
            'WhoIsSethDaniel/mason-tool-installer.nvim',
            'hrsh7th/cmp-nvim-lsp',
        },

        config = function()
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

                    map(
                        '<leader>ca',
                        vim.lsp.buf.code_action,
                        'Code Action',
                        { 'n', 'x' }
                    )
                    map('gD', vim.lsp.buf.declaration, 'Goto Declaration')

                    local client =
                        vim.lsp.get_client_by_id(event.data.client_id)

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

            --------------------------------------------------------
            --                  ENABLED LSP SERVERS                --
            --------------------------------------------------------
            local servers = {
                -- Rust
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

                -- Go
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

                -- TypeScript / JavaScript / React / Next.js
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

                -- Lua
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

                -- C / C++
                clangd = {
                    cmd = {
                        'clangd',
                        '--background-index',
                        '--clang-tidy',
                        '--completion-style=detailed',
                    },
                },

                -- Shell
                bashls = {},

                -- Astro
                astro = {},

                -- CSS (for React/Next.js)
                cssls = {},

                -- Python
                pyright = {},

                -- Docker
                dockerls = {},
                docker_compose_language_service = {},

                -- ESLint
                eslint = {
                    settings = {
                        workingDirectory = {
                            mode = 'auto',
                        },
                    },
                },
                -- Zig
                zls = {
                    settings = {
                        zls = {
                            enable_autofix = true,
                            warn_style = true,
                        },
                    },
                },
            }

            --------------------------------------------------------
            --                MASON INSTALLATION LIST              --
            --------------------------------------------------------
            local ensure_installed = vim.tbl_keys(servers or {})

            vim.list_extend(ensure_installed, {
                'rust_analyzer',
                'gopls',
                'vtsls',
                'lua_ls',
                'bashls',
                'astro',
                'clangd',
                'cssls',
                'dockerls',
                'docker_compose_language_service',
                'pyright',
                'eslint',
            })

            require('mason-tool-installer').setup {
                ensure_installed = ensure_installed,
            }

            require('mason-lspconfig').setup {
                ensure_installed = ensure_installed,
                automatic_installation = false,
                handlers = {
                    function(server_name)
                        local server = servers[server_name] or {}
                        server.capabilities = vim.tbl_deep_extend(
                            'force',
                            {},
                            capabilities,
                            server.capabilities or {}
                        )
                        require('lspconfig')[server_name].setup(server)
                    end,
                },
            }
        end,
    },
}
