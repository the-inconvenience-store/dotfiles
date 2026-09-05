return {
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    opts = require "configs.conform",
  },

  {
    "MunifTanjim/prettier.nvim",
    event = { "BufReadPre", "BufNewFile" },
    cmd = "Prettier",
    dependencies = { "nvimtools/none-ls.nvim" },
    config = function()
      local null_ls = require "null-ls"
      local prettier = require "prettier"
      local prettier_utils = require "prettier.utils"
      local configured = false

      null_ls.setup()

      local function setup_prettier_if_available()
        if configured then
          return
        end

        -- Do not call prettier.setup() until this project has both a
        -- Prettier configuration and a resolvable prettier executable.
        if not prettier.config_exists { check_package_json = true } then
          return
        end
        if not prettier_utils.resolve_bin "prettier" then
          return
        end

        prettier.setup {
          cli_options = {
            config_precedence = "prefer-file",
            tab_width = 2,
            print_width = 80,
            trailing_comma = "all",
            semi = false,
            single_quote = true,
            jsx_single_quote = false,
          },
        }
        configured = true
      end

      local group = vim.api.nvim_create_augroup("PrettierProjectSetup", { clear = true })
      vim.api.nvim_create_autocmd({ "BufEnter", "DirChanged" }, {
        group = group,
        callback = setup_prettier_if_available,
      })
      setup_prettier_if_available()
    end,
  },

  {
    "neovim/nvim-lspconfig",
    lazy = false,
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}

      local required = {
        "vim",
        "lua",
        "vimdoc",
        "html",
        "css",
        "go",
        "gomod",
        "fga",
        "markdown",
        "markdown_inline",
      }
      for _, lang in ipairs(required) do
        if not vim.tbl_contains(opts.ensure_installed, lang) then
          table.insert(opts.ensure_installed, lang)
        end
      end

      local parser_config = require "nvim-treesitter.parsers"
      if not parser_config.fga then
        parser_config.fga = {
          install_info = {
            url = "https://github.com/matoous/tree-sitter-fga",
            files = { "src/parser.c" },
            branch = "main",
            generate_requires_npm = false,
            requires_generate_from_grammar = false,
          },
          filetype = "fga",
        }
      end
    end,
  },

  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      preset = "obsidian",
      completions = { lsp = { enabled = true } },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter-context",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      enable = true,
      max_lines = 4,
      trim_scope = "outer",
      mode = "cursor",
      multiline_threshold = 3,
    },
  },

  {
    "folke/todo-comments.nvim",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      signs = true,
      highlight = {
        keyword = "fg",
        after = "fg",
      },
    },
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next TODO comment" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous TODO comment" },
    },
  },

  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = {
        go = { "golangcilint" },
        -- JavaScript and TypeScript linters are selected per project below:
        -- Oxlint takes precedence when an Oxlint config and executable exist;
        -- ESLint remains the fallback for ESLint projects.
        rust = { "clippy" },
        sh = { "shellcheck" },
        bash = { "shellcheck" },
      }

      local group = vim.api.nvim_create_augroup("NvimLint", { clear = true })
      vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
        group = group,
        callback = function(args)
          local bufnr = args.buf
          local ft = vim.bo[bufnr].filetype
          local filename = vim.api.nvim_buf_get_name(bufnr)
          local dirname = vim.fs.dirname(filename)
          local linter_names
          if ft == "go" then
            local root = vim.fs.find({ "go.mod", "go.work" }, {
              path = dirname,
              upward = true,
              type = "file",
            })[1]
            if not root then
              return
            end
          elseif ft == "rust" then
            -- Clippy invokes Cargo, so avoid running it for loose Rust files
            -- and avoid running it on every InsertLeave event.
            if args.event ~= "BufWritePost" then
              return
            end
            local root = vim.fs.find({ "Cargo.toml" }, {
              path = dirname,
              upward = true,
              type = "file",
            })[1]
            if not root or vim.fn.executable("cargo") ~= 1 then
              return
            end
          elseif ft == "javascript" or ft == "javascriptreact" or ft == "typescript" or ft == "typescriptreact" then
            local oxlint_config = vim.fs.find({
              ".oxlintrc.json",
              ".oxlintrc.jsonc",
              "oxlint.config.js",
              "oxlint.config.mjs",
              "oxlint.config.cjs",
              "oxlint.config.ts",
              "oxlint.config.mts",
              "oxlint.config.cts",
            }, {
              path = dirname,
              upward = true,
              type = "file",
            })[1]
            local eslint_config = vim.fs.find({
              "eslint.config.js",
              "eslint.config.mjs",
              "eslint.config.cjs",
              "eslint.config.ts",
              "eslint.config.mts",
              ".eslintrc",
              ".eslintrc.js",
              ".eslintrc.json",
              "package.json",
            }, {
              path = dirname,
              upward = true,
              type = "file",
            })[1]

            local function project_binary(project_dir, name)
              local path = vim.fs.joinpath(project_dir, "node_modules/.bin/" .. name)
              return vim.fn.executable(path) == 1 and path or nil
            end

            local oxlint_root = oxlint_config and vim.fs.dirname(oxlint_config)
            local eslint_root = eslint_config and vim.fs.dirname(eslint_config)
            local oxlint_bin = oxlint_root and project_binary(oxlint_root, "oxlint")
            local eslint_bin = eslint_root and project_binary(eslint_root, "eslint")

            if oxlint_config and (oxlint_bin or vim.fn.executable("oxlint") == 1) then
              linter_names = { "oxlint" }
            elseif eslint_config and (eslint_bin or vim.fn.executable("eslint") == 1) then
              linter_names = { "eslint" }
            else
              return
            end
          elseif ft ~= "sh" and ft ~= "bash" then
            return
          end
          lint.try_lint(linter_names, { bufnr = bufnr })
        end,
      })
    end,
  },

  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    priority = 1000,
    config = function()
      require("tiny-inline-diagnostic").setup {
        preset = "modern",
        options = {
          show_source = {
            enabled = true,
            if_many = true,
          },
          show_code = true,
          multilines = {
            enabled = true,
            always_show = false,
          },
          override_open_float = true,
        },
      }
      vim.diagnostic.config({ virtual_text = false })
    end,
  },

  {
    "windwp/nvim-ts-autotag",
    opts = {
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = true,
      },
    },
  },

  {
    "catgoose/nvim-colorizer.lua",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("colorizer").setup()
    end,
  },

  {
    "olexsmir/gopher.nvim",
    ft = "go",
    opts = {
      commands = {
        go = "go",
        gomodifytags = "gomodifytags",
        gotests = "gotests",
        impl = "impl",
        iferr = "iferr",
      },
    },
  },

  {
    "mfussenegger/nvim-dap",
    lazy = true,
  },

  {
    "leoluz/nvim-dap-go",
    ft = "go",
    dependencies = "mfussenegger/nvim-dap",
    opts = {},
  },
  {
    "nvim-tree/nvim-tree.lua",
    opts = {
      view = {
        side = "right",
      },
      filters = {
        git_ignored = false,
      },
    },
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
  },

  { "ChmaraX/herdr-nvim", opts = {} },
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      delay = 100,
      large_file_cutoff = 10000,
      filetypes_denylist = {
        "dirbuf",
        "dirvish",
        "fugitive",
        "NvimTree",
      },
    },
    config = function(_, opts)
      require("illuminate").configure(opts)
    end,
  },
  {
    "hedengran/fga.nvim",
    lazy = false,
    opts = {
      install_treesitter_grammar = false,
      -- LSP is configured in configs/lspconfig.lua to avoid load-order issues.
    },
  },
  {
    "mrcjkb/rustaceanvim",
    -- To avoid being surprised by breaking changes,
    -- I recommend you set a version range
    version = "^8",
    -- This plugin implements proper lazy-loading (see :h lua-plugin-lazy).
    -- No need for lazy.nvim to lazy-load it.
    lazy = false,
    init = function()
      vim.g.rustaceanvim = {
        server = {
          cmd = { "lspmux", "client", "--server-path", "rust-analyzer" },
          auto_attach = true,
          before_init = function(params)
            if params.workspaceFolders == nil or params.workspaceFolders == vim.NIL then
              params.workspaceFolders = {}
            end
          end,
          settings = {
            ["rust-analyzer"] = {
              lspMux = {
                version = "1",
                method = "connect",
                server = "rust-analyzer",
              },
            },
          },
        },
      }
    end,
  },
}
