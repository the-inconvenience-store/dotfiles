-- Full startup smoke probe; run via smoke.py with installed plugins.
local function check()
  vim.wait(1000, function() return vim.fn.maparg(";", "n") ~= "" end)
  local plugins = require("lazy.core.config").plugins
  if not require("configs.profile").is_server then
    for _, name in ipairs({ "fff", "conform.nvim", "nvim-lspconfig", "mason.nvim", "rustaceanvim", "fga.nvim", "herdr-nvim" }) do
      assert(plugins[name], "workstation/default must retain " .. name)
    end
    assert(vim.fn.maparg("<leader>ff", "n", false, true).desc == "FFF find files", "retain workstation finder")
    assert(vim.fn.maparg("<leader>fm", "n", false, true).callback, "keep guarded formatter mapping")
    assert(require("chadrc").base46.theme == "gruvchad", "retain workstation theme")
    print("PASS real workstation/default startup, development plugins and guarded mappings")
    return
  end
  for _, name in ipairs({
    "fff", "conform.nvim", "prettier.nvim", "none-ls.nvim", "nvim-lspconfig", "mason.nvim",
    "nvim-lint", "gopher.nvim", "nvim-dap", "nvim-dap-go", "nvim-dap-ui", "nvim-nio",
    "herdr-nvim", "fga.nvim", "rustaceanvim", "nvim-ts-autotag", "tiny-inline-diagnostic.nvim",
  }) do
    assert(not plugins[name], "server resolved spec must omit " .. name)
  end
  assert(plugins["telescope.nvim"] and plugins["nvim-tree.lua"] and plugins.ui, "navigation/UI must remain")
  if vim.fn.has "nvim-0.12" == 0 then
    assert(not plugins["nvim-treesitter"] and not plugins["render-markdown.nvim"]
      and not plugins["nvim-treesitter-context"], "older servers must omit incompatible treesitter plugins")
  else
    assert(plugins["nvim-treesitter"].build == false, "inherited parser build must be disabled")
  end
  assert(require("chadrc").base46.theme == "gruvchad", "keep theme")
  assert(vim.fn.maparg("<C-h>", "n") ~= "", "keep split navigation")
  assert(vim.fn.maparg("jk", "i") == "<Esc>", "keep insert escape")
  assert(vim.fn.maparg("<leader>ff", "n", false, true).desc:lower():find("telescope"), "server ff must use Telescope")
  -- Disabled tooling must not leave a broken inherited format mapping.
  local format = vim.fn.maparg("<leader>fm", "n", false, true)
  assert(format.callback, "keep guarded format mapping")
  format.callback()
  assert(not package.loaded.conform and not package.loaded.fff, "disabled modules must not load")
  assert(vim.g.syntax_on, "server needs syntax fallback without parsers")

  -- Trigger normal editing/filetype/write/insert/user-event paths, not only empty startup.
  for _, file in ipairs({ "example.lua", "example.go", "example.rs", "example.fga", "example.md", "example.sh", "example.json" }) do
    vim.cmd.edit(file)
    vim.api.nvim_exec_autocmds("User", { pattern = "FilePost" })
    vim.api.nvim_exec_autocmds("InsertEnter", {})
    vim.cmd.write()
    vim.api.nvim_exec_autocmds("InsertLeave", {})
  end
  assert(#vim.lsp.get_clients() == 0, "server must not start language servers: " .. vim.inspect(vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients())))
  for _, module in ipairs({ "conform", "lint", "prettier", "lspconfig", "rustaceanvim", "fff" }) do
    assert(not package.loaded[module], "editing must not load " .. module)
  end

  -- Exercise the real file picker and selection, including scheduled mappings.
  vim.fn.maparg("<leader>ff", "n", false, true).callback()
  assert(vim.bo.filetype == "TelescopePrompt", "finder should open")
  local state = require "telescope.actions.state"
  assert(vim.wait(5000, function() return state.get_selected_entry() ~= nil end), "picker must find fixture files")
  local entry = state.get_selected_entry()
  local expected = vim.fn.fnamemodify(entry.path or entry.filename or entry.value, ":p")
  require("telescope.actions").select_default(vim.api.nvim_get_current_buf())
  assert(vim.wait(1000, function() return vim.api.nvim_buf_get_name(0) == expected end), "picker must open selected file")
  vim.cmd.edit "example.lua"
  vim.cmd "normal! gg0w"
  vim.fn.maparg("<leader>fw", "n", false, true).callback()
  assert(vim.bo.filetype == "TelescopePrompt", "word search should open")
  assert(vim.wait(5000, function() return state.get_selected_entry() ~= nil end), "ripgrep word search must return a match")
  require("telescope.actions").close(vim.api.nvim_get_current_buf())
  for _, key in ipairs({ "<leader>fg", "<leader>fz" }) do
    vim.fn.maparg(key, "n", false, true).callback()
    assert(vim.bo.filetype == "TelescopePrompt", key .. " should open a picker")
    require("telescope.actions").close(vim.api.nvim_get_current_buf())
  end
  -- Telescope/NvChad use protected keymap deletion; benign E31 can remain
  -- in v:errmsg even after successful selection. Unhandled errors fail the
  -- probe via xpcall and stderr checks in the runner instead.
  print("PASS real server startup, lazy exclusions, mappings, file editing and Telescope selection")
end
local ok, err = xpcall(check, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd "cquit 1"
else
  vim.cmd "qa!"
end
