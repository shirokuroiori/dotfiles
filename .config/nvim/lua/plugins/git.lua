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
  },
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    cmd = "Octo",
    keys = {
      { "<leader>ol", "<cmd>Octo pr list<cr>", desc = "PR List" },
      { "<leader>os", "<cmd>Octo pr search<cr>", desc = "PR Search" },
      { "<leader>oo", "<cmd>Octo pr checkout<cr>", desc = "PR Checkout" },
      { "<leader>oc", "<cmd>Octo comment add<cr>", desc = "Add Comment" },
      { "<leader>orc", "<cmd>Octo review comments<cr>", desc = "Review Comments" },
      { "<leader>orv", "<cmd>Octo review start<cr>", desc = "Start Review" },
      { "<leader>orx", "<cmd>Octo review submit<cr>", desc = "Submit Review" },
    },
    opts = {},
  },
}
