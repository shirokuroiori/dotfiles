return {
  {
    'shirokuroiori/voltwave.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      require('voltwave').setup({
        bolt = true,
        transparent = false,
        glow = false,
        -- glow_strength = 0.2,
      })
      vim.cmd.colorscheme('voltwave')
      require('lualine').setup({
        options = {
          theme = require('voltwave.extras.lualine').get(),
        },
      })
    end,
  },
  { "Mofiqul/dracula.nvim" },
}
