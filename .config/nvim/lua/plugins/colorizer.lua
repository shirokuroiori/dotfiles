return {
  {
    "roobert/tailwindcss-colorizer-cmp.nvim",
    opts = {
      color_square_width = 6,
    }
  },
  {
    "luckasRanarison/tailwind-tools.nvim",
    name = "tailwind-tools",
    build = ":UpdateRemotePlugins",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-telescope/telescope.nvim", -- optional
      "neovim/nvim-lspconfig",
      "hrsh7th/cmp-nvim-lsp", -- capabilities 用（vim.lsp.config と揃える）
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
      local ok_cmp, cmp_lsp = pcall(require, "cmp_nvim_lsp")
      if ok_cmp then
        caps = cmp_lsp.default_capabilities()
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
    event = "BufReadPre",
    opts = {
      filetypes = { "*" },
    },
    config = function(_, opts)
      require("colorizer").setup(opts)
    end,
  },
}
