return {
  {
    "s1n7ax/nvim-window-picker",
    keys = {
      { "n", "<leader>wp", ":WindowPicker<CR>", desc = "Window Picker" },
    },
    opts = {
      autoselect_one = true,
      include_current = false,
      filter_rules = {
        -- filter using buffer options
        bo = {
          -- if the file type is one of following, the window will be ignored
          filetype = {
            "neo-tree",
            "neo-tree-popup",
            "notify",
            "packer",
            "qf",
            "diff",
            "fugitive",
            "fugitiveblame",
          },

          -- if the buffer type is one of following, the window will be ignored
          buftype = { "nofile", "help", "terminal" },
        },
      },
      fg_color = "#1d2021",
      other_win_hl_color = "#fe8019",
    },
  },
}
