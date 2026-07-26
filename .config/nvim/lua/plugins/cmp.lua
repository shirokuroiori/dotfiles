return {
  {
    "saghen/blink.cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    version = "1.*",
    dependencies = {
      "L3MON4D3/LuaSnip",           -- スニペットエンジン
      "rafamadriz/friendly-snippets", -- スニペット集（任意）
    },
    opts = {
      -- Tab補完でsnippetジャンプまで行う従来の挙動に合わせるプリセット
      keymap = { preset = "super-tab" },
      snippets = { preset = "luasnip" },
      appearance = {
        nerd_font_variant = "mono",
      },
      completion = {
        menu = {
          border = "rounded",
        },
        documentation = {
          auto_show = true,
          window = { border = "rounded" },
        },
      },
      signature = {
        enabled = true,
        window = { border = "rounded" },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
      },
      cmdline = {
        enabled = true,
      },
    },
    config = function(_, opts)
      require("luasnip.loaders.from_vscode").lazy_load()
      require("blink.cmp").setup(opts)
    end,
  },
}
