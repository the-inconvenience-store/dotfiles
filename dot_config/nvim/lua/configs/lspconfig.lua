require("nvchad.configs.lspconfig").defaults()

local nvlsp = require "nvchad.configs.lspconfig"

local function mux_cmd(server, args)
  local cmd = { "lspmux", "client", "--server-path", server }
  if args and #args > 0 then
    table.insert(cmd, "--")
    vim.list_extend(cmd, args)
  end
  return cmd
end

local function direct_cmd(server, args)
  local cmd = { server }
  vim.list_extend(cmd, args or {})
  return cmd
end

local function mux_before_init(params)
  -- lspmux 0.3 expects a sequence here; Neovim sends null when no folders
  -- were explicitly supplied.
  if params.workspaceFolders == nil or params.workspaceFolders == vim.NIL then
    params.workspaceFolders = {}
  end
end

local function mux_config(server, args)
  return {
    cmd = mux_cmd(server, args),
    before_init = mux_before_init,
  }
end

local function tailwind_root_dir(bufnr, on_dir)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local marker = vim.fs.find({
    "tailwind.config.js",
    "tailwind.config.cjs",
    "tailwind.config.mjs",
    "tailwind.config.ts",
    "postcss.config.js",
    "postcss.config.cjs",
    "postcss.config.mjs",
    "postcss.config.ts",
    "package.json",
    ".git",
  }, {
    path = vim.fs.dirname(filename),
    upward = true,
  })[1]
  if not marker then
    return
  end

  local root = vim.fs.dirname(marker)
  while root do
    local package_file = vim.fs.joinpath(root, "node_modules/tailwindcss/package.json")
    if vim.fn.filereadable(package_file) == 1 then
      on_dir(root)
      return
    end
    local parent = vim.fs.dirname(root)
    if parent == root then
      return
    end
    root = parent
  end
end

-- Servers with server-to-client protocol requirements stay direct.
local servers = { "html", "cssls", "golangci_lint_ls", "tailwindcss" }
local server_configs = {
  html = { cmd = direct_cmd("vscode-html-language-server", { "--stdio" }) },
  cssls = { cmd = direct_cmd("vscode-css-language-server", { "--stdio" }) },
  golangci_lint_ls = { cmd = direct_cmd("golangci-lint-langserver") },
  tailwindcss = {
    cmd = direct_cmd("tailwindcss-language-server", { "--stdio" }),
    root_dir = tailwind_root_dir,
  },
}
for name, config in pairs(server_configs) do
  vim.lsp.config(name, config)
end
vim.lsp.enable(servers)

-- gopls with custom settings and Go keymaps
vim.lsp.config("gopls", {
  cmd = mux_cmd("gopls"),
  before_init = mux_before_init,
  on_attach = function(client, bufnr)
    nvlsp.on_attach(client, bufnr)
    pcall(vim.lsp.codelens.refresh)

    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { silent = true, desc = desc, buffer = bufnr, noremap = true })
    end

    map("n", "<leader>Ci", "<cmd>GoInstallDeps<cr>", "Install Go Dependencies")
    map("n", "<leader>Ct", "<cmd>GoMod tidy<cr>", "Tidy")
    map("n", "<leader>Ca", "<cmd>GoTestAdd<cr>", "Add Test")
    map("n", "<leader>CA", "<cmd>GoTestsAll<cr>", "Add All Tests")
    map("n", "<leader>Ce", "<cmd>GoTestsExp<cr>", "Add Exported Tests")
    map("n", "<leader>Cg", "<cmd>GoGenerate<cr>", "Go Generate")
    map("n", "<leader>Cf", "<cmd>GoGenerate %<cr>", "Go Generate File")
    map("n", "<leader>Cc", "<cmd>GoCmt<cr>", "Generate Comment")
    map("n", "<leader>DT", function() require("dap-go").debug_test() end, "Debug Test")
  end,
  on_init = nvlsp.on_init,
  capabilities = nvlsp.capabilities,
  settings = {
    gopls = {
      usePlaceholders = true,
      gofumpt = true,
      codelenses = {
        generate = false,
        gc_details = true,
        test = true,
        tidy = true,
      },
    },
  },
})
vim.lsp.enable("gopls")

-- OpenFGA LSP: start directly on fga buffers to avoid plugin load-order races.
local openfga_lsp_server = vim.env.OPENFGA_LSP_SERVER or vim.fn.expand("~/dev/vscode-ext/server/out/server.node.js")

if vim.fn.filereadable(openfga_lsp_server) == 1 then
  local openfga_group = vim.api.nvim_create_augroup("OpenFGALsp", { clear = true })

  local function start_openfga(bufnr)
    if vim.bo[bufnr].filetype ~= "fga" then
      return
    end

    local existing = vim.lsp.get_clients({ bufnr = bufnr, name = "openfga" })
    if #existing > 0 then
      return
    end

    local filename = vim.api.nvim_buf_get_name(bufnr)
    local root_dir = vim.fs.root(filename, { ".git" }) or vim.fs.dirname(filename) or vim.loop.cwd()

    vim.lsp.start({
      name = "openfga",
      cmd = mux_cmd("node", { openfga_lsp_server, "--stdio" }),
      before_init = mux_before_init,
      root_dir = root_dir,
      on_attach = nvlsp.on_attach,
      on_init = nvlsp.on_init,
      capabilities = nvlsp.capabilities,
    }, { bufnr = bufnr })
  end

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = openfga_group,
    pattern = "*.fga",
    callback = function(args)
      start_openfga(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    group = openfga_group,
    pattern = "fga",
    callback = function(args)
      start_openfga(args.buf)
    end,
  })
else
  vim.notify("openfga LSP server not found: " .. openfga_lsp_server, vim.log.levels.WARN)
end
