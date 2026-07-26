return {
  {
    "luckasRanarison/tailwind-tools.nvim",
    name = "tailwind-tools",
    ft = { "css", "scss", "sass", "less", "html", "vue", "javascript", "javascriptreact", "typescript", "typescriptreact" },
    build = ":UpdateRemotePlugins",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-telescope/telescope.nvim", -- optional
      "neovim/nvim-lspconfig",
      "saghen/blink.cmp", -- capabilities 用（vim.lsp.config と揃える）
    },
    opts = {
      -- lspconfig.tailwindcss.setup は非推奨; vim.lsp.config で登録する（下の config）
      server = { override = false },
    },
    config = function(_, opts)
      require("tailwind-tools").setup(opts)

      local tw_lsp = require("tailwind-tools.lsp")
      local filetypes = require("tailwind-tools.filetypes")
      local srv = opts.server or { settings = {} }
      local st = srv.settings or {}

      local tailwindCSS = vim.tbl_deep_extend(
        "keep",
        vim.tbl_get(st, "tailwindCSS") or {},
        st
      )
      tailwindCSS.includeLanguages = vim.tbl_extend(
        "keep",
        st.includeLanguages or {},
        filetypes.get_server_map()
      )

      local caps = vim.lsp.protocol.make_client_capabilities()
      local ok_blink, blink_cmp = pcall(require, "blink.cmp")
      if ok_blink then
        caps = blink_cmp.get_lsp_capabilities()
      end
      caps.textDocument = caps.textDocument or {}
      caps.textDocument.colorProvider = { dynamicRegistration = true }

      vim.lsp.config("tailwindcss", {
        capabilities = caps,
        on_attach = tw_lsp.make_on_attach(srv.on_attach),
        settings = { tailwindCSS = tailwindCSS },
      })
      vim.lsp.enable("tailwindcss")
    end,
  },
  {
    "catgoose/nvim-colorizer.lua",
    ft = {
      "css", "scss", "sass", "less",
      "html", "vue",
      "javascript", "javascriptreact", "typescript", "typescriptreact",
      "lua", "json", "jsonc", "yaml", "toml", "conf", "vim",
    },
    opts = {
      filetypes = {
        "css", "scss", "sass", "less",
        "html", "vue",
        "javascript", "javascriptreact", "typescript", "typescriptreact",
        "lua", "json", "jsonc", "yaml", "toml", "conf", "vim",
      },
    },
    config = function(_, opts)
      require("colorizer").setup(opts)
    end,
  },
}
