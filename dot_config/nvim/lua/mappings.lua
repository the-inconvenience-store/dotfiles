require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- Option + Left/Right to move by word in insert mode
map("i", "<A-b>", "<C-o>b", { desc = "Move word left" })
map("i", "<A-f>", "<C-o>w", { desc = "Move word right" })

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
