return {{
    'neovim/nvim-lspconfig',
    opts = {
        servers = {
            -- Disable upcoming ts_ls server cleanly
            ts_ls = {
                enabled = false
            },

            -- VTSLS (best TS LSP)
            vtsls = {
                filetypes = {'javascript', 'javascriptreact', 'javascript.jsx', 'typescript', 'typescriptreact',
                             'typescript.tsx'},
                settings = {
                    complete_function_calls = true,
                    vtsls = {
                        enableMoveToFileCodeAction = true,
                        autoUseWorkspaceTsdk = true,
                        experimental = {
                            maxInlayHintLength = 30,
                            completion = {
                                enableServerSideFuzzyMatch = true
                            }
                        }
                    },
                    typescript = {
                        updateImportsOnFileMove = {
                            enabled = 'always'
                        },
                        suggest = {
                            completeFunctionCalls = true
                        },
                        inlayHints = {
                            enumMemberValues = {
                                enabled = true
                            },
                            functionLikeReturnTypes = {
                                enabled = true
                            },
                            parameterNames = {
                                enabled = 'literals'
                            },
                            parameterTypes = {
                                enabled = true
                            },
                            propertyDeclarationTypes = {
                                enabled = true
                            },
                            variableTypes = {
                                enabled = false
                            }
                        }
                    }
                },

                keys = {{
                    'gD',
                    function()
                        local pos = vim.lsp.util.make_position_params()
                        local params = {
                            command = 'typescript.goToSourceDefinition',
                            arguments = {pos.textDocument.uri, pos.position}
                        }
                        require("trouble").open({
                            mode = "lsp_command",
                            params = params
                        })
                    end,
                    desc = 'Goto Source Definition'
                }, {
                    'gR',
                    function()
                        require("trouble").open({
                            mode = "lsp_command",
                            params = {
                                command = 'typescript.findAllFileReferences',
                                arguments = {vim.uri_from_bufnr(0)}
                            }
                        })
                    end,
                    desc = 'File References'
                }, {
                    '<leader>co',
                    '<cmd>VtsExec organize_imports<cr>',
                    desc = 'Organize Imports'
                }, {
                    '<leader>cM',
                    '<cmd>VtsExec add_missing_imports<cr>',
                    desc = 'Add Missing Imports'
                }, {
                    '<leader>cu',
                    '<cmd>VtsExec remove_unused_imports<cr>',
                    desc = 'Remove Unused Imports'
                }, {
                    '<leader>cD',
                    '<cmd>VtsExec fix_all<cr>',
                    desc = 'Fix All Diagnostics'
                }, {
                    '<leader>cV',
                    '<cmd>VtsExec select_ts_version<cr>',
                    desc = 'Select TS Version'
                }}
            }
        },

        setup = {
            -- disable ts_ls cleanly
            ts_ls = function()
                return true
            end,

            vtsls = function(_, opts)
                local function on_attach(client, bufnr)
                    client.commands['_typescript.moveToFileRefactoring'] = function(cmd)
                        local action, uri, range = unpack(cmd.arguments)
                        local function move(to)
                            client.request('workspace/executeCommand', {
                                command = cmd.command,
                                arguments = {action, uri, range, to}
                            })
                        end

                        local file = vim.uri_to_fname(uri)
                        client.request('workspace/executeCommand', {
                            command = 'vtsls.tsserverRequest',
                            arguments = {'getMoveToRefactoringFileSuggestions', {
                                file = file,
                                startLine = range.start.line + 1,
                                startOffset = range.start.character + 1,
                                endLine = range['end'].line + 1,
                                endOffset = range['end'].character + 1
                            }}
                        }, function(_, res)
                            local files = res.body.files
                            table.insert(files, 1, 'Enter new path...')
                            vim.ui.select(files, {
                                prompt = 'Select move destination:',
                                format_item = function(f)
                                    return vim.fn.fnamemodify(f, ':~:.')
                                end
                            }, function(f)
                                if not f then
                                    return
                                end
                                if f:find('Enter new path') then
                                    vim.ui.input({
                                        prompt = 'Enter destination:',
                                        default = vim.fn.fnamemodify(file, ':h') .. '/',
                                        completion = 'file'
                                    }, function(path)
                                        if path then
                                            move(path)
                                        end
                                    end)
                                else
                                    move(f)
                                end
                            end)
                        end)
                    end
                end

                vim.api.nvim_create_autocmd("LspAttach", {
                    callback = function(args)
                        local client = vim.lsp.get_client_by_id(args.data.client_id)
                        if client and client.name == "vtsls" then
                            on_attach(client, args.buf)
                        end
                    end
                })

                opts.settings.javascript = vim.tbl_deep_extend("force", {}, opts.settings.typescript,
                    opts.settings.javascript or {})
            end
        }
    }
}}
