return {
  {
    'shirokuroiori/voltwave.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      require('voltwave').setup({
        bolt = true,
        transparent = true,
        glow = true,
        glow_strength = 0.2,
      })
      vim.cmd.colorscheme('voltwave')
      require('lualine').setup({
        options = {
          theme = require('voltwave.extras.lualine').get(),
        },
      })
    end,
  },
  {
    'maxmx03/fluoromachine.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      local fm = require 'fluoromachine'
      fm.setup {
        glow = true,
        theme = 'fluoromachine',
        transparent = true,
      }
      -- vim.cmd.colorscheme 'fluoromachine'
    end
  }
}
