-- Run without plugins: NVIM_CONFIG_ROOT=... nvim --headless -u NONE -l tests/profile_spec.lua
local root = assert(vim.env.NVIM_CONFIG_ROOT, "set NVIM_CONFIG_ROOT to the config source")
for _, path in ipairs(vim.fn.glob(root .. "/**/*.lua", false, true)) do
  assert(loadfile(path), "Lua syntax failed: " .. path)
end
print("PASS Lua syntax")
package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local function specs(profile)
  package.loaded.machine = nil
  package.loaded["configs.profile"] = nil
  package.loaded["configs.conform"] = nil
  package.preload.machine = profile and function() return { profile = profile } end or nil
  local result = {}
  for _, spec in ipairs(dofile(root .. "/lua/plugins/init.lua")) do
    result[spec[1]] = spec
  end
  return result
end

local server = specs("server")
assert(server["dmtrKovalenko/fff"].enabled == false, "server must disable fff and its native build")
print("PASS server disables native finder")

local development = {
  "stevearc/conform.nvim", "MunifTanjim/prettier.nvim", "neovim/nvim-lspconfig",
  "nvimtools/none-ls.nvim", "nvim-neotest/nvim-nio",
  "mason-org/mason.nvim", "mfussenegger/nvim-lint", "olexsmir/gopher.nvim",
  "mfussenegger/nvim-dap", "leoluz/nvim-dap-go", "rcarriga/nvim-dap-ui",
  "ChmaraX/herdr-nvim", "hedengran/fga.nvim", "mrcjkb/rustaceanvim",
  "windwp/nvim-ts-autotag", "rachartier/tiny-inline-diagnostic.nvim",
}
for _, name in ipairs(development) do
  assert(server[name] and server[name].enabled == false, "server must disable " .. name)
end
-- Direct/manual requires must not re-enable LSP or formatter configuration.
assert(pcall(dofile, root .. "/lua/configs/lspconfig.lua"), "server LSP config must be a no-op without NvChad")
assert(vim.tbl_isempty(dofile(root .. "/lua/configs/conform.lua")), "server must not configure formatters")
print("PASS server disables language tooling")

local treesitter = server["nvim-treesitter/nvim-treesitter"]
assert(treesitter.build == false, "server must not build parsers without an optional tree-sitter CLI")
local opts = { ensure_installed = { "html", "css", "luadoc", "printf" }, auto_install = true }
treesitter.opts(nil, opts)
assert(vim.deep_equal(opts.ensure_installed, {
  "vim", "lua", "vimdoc", "bash", "json", "yaml", "markdown", "markdown_inline",
}), "server parser list must replace inherited development parsers")
assert(opts.auto_install == false, "server parser installation must be opt-in")
print("PASS server parsers are restricted and opt-in")

for _, profile in ipairs({ "workstation", "missing", "unknown" }) do
  local workstation = specs(profile ~= "missing" and profile or nil)
  assert(workstation["dmtrKovalenko/fff"].enabled ~= false, profile .. " must retain fff")
  assert(type(workstation["dmtrKovalenko/fff"].build) == "function", "retain workstation native build")
  assert(workstation["stevearc/conform.nvim"].opts.formatters_by_ft.go[1] == "goimports", "retain workstation formatting")
  for _, name in ipairs(development) do
    assert(not workstation[name] or workstation[name].enabled ~= false, profile .. " must retain " .. name)
  end
end
print("PASS workstation, absent and unknown markers retain development plugins")

-- Test the older-server dependency cut without requiring an older binary.
local has = vim.fn.has
vim.fn.has = function(feature)
  return feature == "nvim-0.12" and 0 or has(feature)
end
local old = specs("server")
vim.fn.has = has
for _, name in ipairs({ "nvim-treesitter/nvim-treesitter", "nvim-treesitter/nvim-treesitter-context", "MeanderingProgrammer/render-markdown.nvim" }) do
  assert(old[name].enabled == false, "Neovim 0.11 must omit incompatible " .. name)
end
print("PASS Neovim 0.11 server dependency fallback (simulated version check)")
