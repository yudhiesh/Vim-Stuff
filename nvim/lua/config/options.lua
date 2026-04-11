-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
vim.g.lazyvim_picker = "telescope"

do
  local diagnostic_config = vim.diagnostic.config

  vim.diagnostic.config = function(opts, ...)
    local ok, result = pcall(diagnostic_config, opts, ...)
    if ok then
      return result
    end

    if type(opts) == "table" and tostring(result):match("Invalid buffer id:") then
      vim.diagnostic.reset()
      return diagnostic_config(opts, ...)
    end

    error(result)
  end
end
