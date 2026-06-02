-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local cuda = require("config.cuda")

vim.keymap.set("n", "<leader>ma", cuda.open_alternate, { desc = "CUDA Alternate File" })
vim.keymap.set("n", "<leader>md", cuda.debug_current_test, { desc = "CUDA Debug Current Test" })
vim.keymap.set("n", "<leader>mh", cuda.verify_hardware, { desc = "CUDA Verify Hardware" })
vim.keymap.set("n", "<leader>mt", cuda.run_current_test, { desc = "CUDA Test Current" })
vim.keymap.set("n", "<leader>mT", cuda.run_all_tests, { desc = "CUDA Test All" })
