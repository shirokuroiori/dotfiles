return {
  "RRethy/vim-illuminate",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    delay = 100,
    large_file_cutoff = 2000,
    providers = { "lsp", "regex" },
  },
  config = function(_, opts)
    require("illuminate").configure(opts)
    vim.api.nvim_set_hl(0, "IlluminatedWordText",  { bg = "#3d3d3d" })
    vim.api.nvim_set_hl(0, "IlluminatedWordRead",  { bg = "#3d3d3d" })
    vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { bg = "#3d3d3d" })
  end,
}
