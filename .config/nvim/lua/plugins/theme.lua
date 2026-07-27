return {
  {
    'shirokuroiori/voltwave.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      require('voltwave').setup({
        bolt = true,
        transparent = true,
        glow = false,
        italic = {
          comments   = false,
          functions  = false,
          variables  = false,
        },
      })
      vim.cmd.colorscheme('voltwave')
    end,
  },
}
