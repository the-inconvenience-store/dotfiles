require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

-- fff replaces the file finder; other Telescope pickers remain available.
map("n", "<leader>ff", function() require("fff").find_files() end, { desc = "FFF find files" })
map("n", "<leader>fg", function() require("fff").live_grep() end, { desc = "FFF live grep" })
map("n", "<leader>fz", function()
  require("fff").live_grep { grep = { modes = { "fuzzy", "plain" } } }
end, { desc = "FFF fuzzy grep" })
map({ "n", "x" }, "<leader>fw", function() require("fff").live_grep_under_cursor() end,
  { desc = "FFF search word or selection" })

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- Option + Left/Right to move by word in insert mode
map("i", "<A-b>", "<C-o>b", { desc = "Move word left" })
map("i", "<A-f>", "<C-o>w", { desc = "Move word right" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
