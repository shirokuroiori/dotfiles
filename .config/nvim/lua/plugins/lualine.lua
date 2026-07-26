return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  dependencies = { "DaikyXendo/nvim-material-icon" },
  init = function()
    vim.o.laststatus = 0
    vim.o.showtabline = 0
  end,
  opts = function()
    return {
      options = {
        icons_enabled = true,
        theme = require('voltwave.extras.lualine').get(),
        always_show_tabline = true,
        globalstatus = true,
        -- section_separators = { left = '', right = '' },
        -- component_separators = { left = '', right = '' },
      },
      sections = {
        lualine_b = {
          'branch',
          {
            'diff',
            symbols = { added = ' ', modified = ' ', removed = ' ' },
          },
        },
        lualine_c = {
          {
            'diagnostics',
            sections = { 'error', 'warn', 'hint', 'info' },
            symbols = { error = ' ', warn = ' ', hint = '󰌵', info = ' ' },
          },
          {
            'lsp_status',
            icon = '', -- f013
            symbols = {
              -- Standard unicode symbols to cycle through for LSP progress:
              spinner = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' },
              -- Standard unicode symbol for when LSP is done:
              done = '󰩐 ',
              -- Delimiter inserted between LSP names:
              separator = ' ',
            },
            -- List of LSP names to ignore (e.g., `null-ls`):
            ignore_lsp = {},
          },
        },
        lualine_y = {
          'location',
          'progress',
        },
        lualine_z = {
          function()
            return "  " .. os.date("%R")
          end,
        },
      },
    }
  end,
}
