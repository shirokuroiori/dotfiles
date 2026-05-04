-- lua/plugins/git.lua
return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    keys = {
      { "<leader>gb", function() require("gitsigns").blame_line({ full = true }) end, desc = "Git blame line" },
    },
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "┃" },
          change = { text = "┋" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
        },
        signs_staged = {
          add = { text = "┃" },
          change = { text = "┋" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
        },
        sign_priority = 20,
        preview_config = {
          border = "rounded",
        },
        current_line_blame = true,
        current_line_blame_opts = {
          delay = 500,
          virt_text_pos = "eol",
        },
      })
    end,
  },
  {
    "kdheepak/lazygit.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = {
      "Lazygit",
      "LazygitConfig",
      "LazygitCurrentFile",
      "LazygitFilter",
      "LazygitFilterCurrentFile",
    },
    keys = {
      { "<leader>G", "<cmd>LazyGit<cr>", desc = "LazyGit" }
    }
  },
  {
    "esmuellert/codediff.nvim",
    cmd = "CodeDiff",
    keys = {
      { "<leader>d", nil, desc = "Code Diff", icon = "" },
      { "<leader>do", "<cmd>CodeDiff<cr>", desc = "Open" },
    },
    opts = {
      highlights = {
        char_brightness = 2.0
      }
    }
  }
}
