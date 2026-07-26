return {
  "lewis6991/satellite.nvim",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    require("satellite").setup({
      current_only = false,
      winblend = 50,
      zindex = 40,
      width = 2,
      handlers = {
        cursor = {
          enable = true,
          symbols = { "⎺", "⎻", "⎼", "⎽" },
        },
        search = {
          enable = true,
        },
        diagnostic = {
          enable = true,
          signs = { "-", "=", "≡" },
          min_severity = vim.diagnostic.severity.HINT,
        },
        gitsigns = {
          enable = true,
          signs = {
            add = "┃",
            change = "┋",
            delete = "_",
          },
        },
        marks = {
          enable = true,
          show_builtins = false,
        },
        quickfix = {
          enable = true,
        },
      },
    })
  end,
}
