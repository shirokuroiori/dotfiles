return {
  -- mason
  {
    "williamboman/mason.nvim",
    config = true,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "mason.nvim", "neovim/nvim-lspconfig" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          "pyright",
          "ruff",
          "ts_ls",
          "lua_ls",
          "tailwindcss",
        },
      })
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      vim.lsp.config("*", {
        capabilities = capabilities,
      })
    end,
  },
  {
    "nvimdev/lspsaga.nvim",
    event = "LspAttach",
    dependencies = {
      "nvim-treesitter/nvim-treesitter", -- optional
      "DaikyXendo/nvim-material-icon", -- optional（nvim-web-devicons と同一 API）
    },
    opts = {
      server_filetype_map = {
        typescript = "typescript",
      },
      diagnostic_only_current = true,
      symbol_in_winbar = {
        enable = true,
      },
      code_action = {
        quit = 'q',
        num_shortcut = true,
        show_server_name = false,
        extend_gitsigns = true,
      },
      finder = {
        max_height = 0.8,
        right_width = 0.5,
        keys = {
          vsplit = 'v',
        },
      },
      diagnostic = {
        show_code_action = true,
        show_layout = 'float',
        jump_num_shortcut = true,
        signs = {
          active = true,
          priority = 30, -- gitsignsより高い優先度
        },
      },
      lightbulb = {
        enable = true,
        enable_in_insert = true,
        sign = false,             -- サイン列に電球を表示しない
        virtual_text = true,      -- 仮想テキストで行末に表示
        virtual_text_pos = 'eol', -- 行末に表示
        sign_priority = 30,
      },
    },
    config = function(_, opts)
      require("lspsaga").setup(opts)

      -- Neovimの診断設定をlspsagaと連携
      vim.diagnostic.config({
        virtual_text = true,      -- 仮想テキストを有効化
        underline = true,         -- 下線を有効化
        update_in_insert = false, -- 挿入モード中は更新しない
      })
    end,
    keys = {
      { "gp",    "<Cmd>Lspsaga peek_definition<CR>",      mode = "n", noremap = true,      silent = true, desc = "LSP: Preview definition" },
      { "gj",    "<Cmd>Lspsaga goto_definition<CR>",      mode = "n", noremap = true,      silent = true, desc = "LSP: goto_definition" },
      { "gtp",   "<Cmd>Lspsaga peek_type_definition<CR>", mode = "n", noremap = true,      silent = true, desc = "LSP: Peek type definition" },
      { "gf",    "<Cmd>Lspsaga finder<CR>",               mode = "n", desc = "LSP: finder" },
      { "gh",    "<Cmd>Lspsaga hover_doc<CR>",            mode = "n", noremap = true,      silent = true, desc = "LSP: Hover doc" },
      { "gr",    "<Cmd>Lspsaga rename<CR>",               mode = "n", noremap = true,      silent = true, desc = "LSP: Rename" },
      { "ga",    "<Cmd>Lspsaga code_action<CR>",          mode = "n", desc = "LSP: Code action" },
      -- { "ll",    "<Cmd>Lspsaga code_action<CR>",          mode = "n", noremap = true,      silent = true, desc = "LSP: code action" },
      -- { "gj", "<Cmd>Lspsaga diagnostic_jump_next<CR>", mode = "n", noremap = true, silent = true, desc = "LSP: Next diagnostic" },
      { "gd",    "<Cmd>Lspsaga finder<CR>",               mode = "n", noremap = true,      silent = true, desc = "LSP: Finder" },
      { "<C-k>", "<Cmd>Lspsaga signature_help<CR>",       mode = "i", noremap = true,      silent = true, desc = "LSP: Signature help" },
    },
  }
}
