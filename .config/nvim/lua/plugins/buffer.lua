return {
  'akinsho/bufferline.nvim',
  version = "*",
  dependencies = "DaikyXendo/nvim-material-icon",
  event = "VeryLazy",
  init = function()
    vim.o.showtabline = 0
  end,
  keys = {
    { "<C-]>", "<cmd>bnext<CR>" },
    { "<C-[>", "<cmd>bprev<CR>" },
  },
  opts = {
    options = {
      numbers = "buffer_id",
      offsets = {
        {
          filetype = "neo-tree",
          text = "File Explorer",
          highlight = "Directory",
          separator = true -- use a "true" to enable the default, or set your own character
        }
      },
      separator_style = "slant",
    }
  }
}
