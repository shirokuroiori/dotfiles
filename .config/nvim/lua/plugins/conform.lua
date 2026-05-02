return {
  "stevearc/conform.nvim",
  dependencies = { "williamboman/mason.nvim" },
  event = { "BufWritePre" },
  config = function()
    require("conform").setup({
      formatters_by_ft = {
        python = { "ruff_format", "ruff_fix" }, -- or "black"
      },
      format_on_save = nil,
    })
  end,
}
