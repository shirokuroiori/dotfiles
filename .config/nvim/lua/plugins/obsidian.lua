return {
  "obsidian-nvim/obsidian.nvim",
  version = "*",
  ft = "markdown",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  opts = {
    legacy_commands = false, -- ":Obsidian <subcommand>" 形式のみ使う
    workspaces = {
      { name = "vault", path = "~/obsidian/vault" },
    },
    picker = {
      name = "telescope.nvim",
    },
    completion = {
      min_chars = 2,
    },
    ui = {
      -- 見た目(concealによるチェックボックス/箇条書き装飾)は markview.nvim に任せる
      enable = false,
    },
  },
  keys = {
    { "<leader>no", "<cmd>Obsidian open<cr>", desc = "Obsidian: Open in app" },
    { "<leader>nn", "<cmd>Obsidian new<cr>", desc = "Obsidian: New note" },
    { "<leader>nf", "<cmd>Obsidian quick_switch<cr>", desc = "Obsidian: Quick switch" },
    { "<leader>ns", "<cmd>Obsidian search<cr>", desc = "Obsidian: Search" },
    { "<leader>nt", "<cmd>Obsidian tags<cr>", desc = "Obsidian: Tags" },
    { "<leader>nd", "<cmd>Obsidian today<cr>", desc = "Obsidian: Today's daily note" },
    { "<leader>nb", "<cmd>Obsidian backlinks<cr>", desc = "Obsidian: Backlinks" },
    { "<leader>nl", "<cmd>Obsidian follow_link<cr>", desc = "Obsidian: Follow link" },
    { "<leader>nc", "<cmd>Obsidian toggle_checkbox<cr>", desc = "Obsidian: Toggle checkbox" },
    { "<leader>nr", "<cmd>Obsidian rename<cr>", desc = "Obsidian: Rename note" },
  },
}
