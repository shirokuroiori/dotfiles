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
        -- glow_strength = 0.2,
      })
      vim.cmd.colorscheme('voltwave')
    end,
  },
}
