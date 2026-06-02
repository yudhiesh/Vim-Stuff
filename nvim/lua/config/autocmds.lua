-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here
vim.opt.swapfile = false

require("config.cuda").setup()

vim.api.nvim_create_autocmd("FileType", {
  pattern = "cuda",
  callback = function(event)
    vim.bo[event.buf].commentstring = "// %s"
    vim.bo[event.buf].shiftwidth = 2
    vim.bo[event.buf].tabstop = 2
    vim.bo[event.buf].expandtab = true
  end,
})
