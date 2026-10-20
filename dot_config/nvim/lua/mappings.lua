require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

-- Keep the same finder keys on servers without fff's native binary.
local server = require("configs.profile").is_server
local function picker(fff_method, telescope_method, opts)
  return function()
    if not server then
      local ok, fff = pcall(require, "fff")
      if ok then
        fff[fff_method](opts)
        return
      end
    end
    require("telescope.builtin")[telescope_method]()
  end
end
local finder = server and "Telescope" or "FFF"
map("n", "<leader>ff", picker("find_files", "find_files"), { desc = finder .. " find files" })
map("n", "<leader>fg", picker("live_grep", "live_grep"), { desc = finder .. " live grep" })
map("n", "<leader>fz", picker("live_grep", "current_buffer_fuzzy_find", {
  grep = { modes = { "fuzzy", "plain" } },
}), { desc = server and "Telescope fuzzy buffer search" or "FFF fuzzy grep" })
map({ "n", "x" }, "<leader>fw", picker("live_grep_under_cursor", "grep_string"),
  { desc = finder .. " search word or selection" })

-- NvChad's stock format mapping requires conform, which is disabled on servers.
map({ "n", "x" }, "<leader>fm", function()
  if not server then
    local ok, conform = pcall(require, "conform")
    if ok then
      conform.format { lsp_fallback = true }
      return
    end
  end
  vim.notify("Formatting tools are disabled for this profile", vim.log.levels.INFO)
end, { desc = "Format file (when tooling is enabled)" })

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- Option + Left/Right to move by word in insert mode
map("i", "<A-b>", "<C-o>b", { desc = "Move word left" })
map("i", "<A-f>", "<C-o>w", { desc = "Move word right" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
