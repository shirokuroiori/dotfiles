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
    },
    -- LazyGit runs as a :terminal job in a floating window (LAZYGIT_BUFFER is
    -- a real Lua global set by lazygit.lua, not `local`). LazyGitQuitThen
    -- sends lazygit's own quit key so the job exits normally -- that's what
    -- makes lazygit.lua's on_exit() actually close the float, restore focus
    -- to the window LazyGit was opened from, and run lazygit_on_exit_callback.
    -- Without going through a real quit, the job just keeps running hidden
    -- behind whatever we open next, which is why closing used to take two
    -- steps. See .config/lazygit/config.yml for the customCommands that call
    -- this via `nvim --server "$NVIM" --remote-send`.
    init = function()
      _G.LazyGitQuitThen = function(after)
        local buf = _G.LAZYGIT_BUFFER
        local job_id = buf and vim.api.nvim_buf_is_valid(buf) and vim.b[buf].terminal_job_id
        if not job_id then
          after()
          return
        end
        vim.g.lazygit_on_exit_callback = function()
          vim.g.lazygit_on_exit_callback = nil
          after()
        end
        vim.fn.chansend(job_id, "q")
      end

      _G.LazyGitOpenFile = function(file)
        _G.LazyGitQuitThen(function()
          vim.cmd.edit(vim.fn.fnameescape(file))
        end)
      end
    end,
  },
  {
    "esmuellert/codediff.nvim",
    cmd = "CodeDiff",
    keys = {
      { "<leader>d", nil, desc = "Code Diff", icon = "" },
      { "<leader>do", "<cmd>CodeDiff<cr>", desc = "Open" },
    },
    opts = {
      explorer = {
        view_mode = "tree",
      },
      highlights = {
        char_brightness = 2.0
      }
    },
    -- :CodeDiffFile <path> opens <path> and drops straight into CodeDiff's
    -- explorer (tree + stage/unstage), focused on that file. Exposed as a
    -- global fn too so LazyGit can reach into this Neovim instance via
    -- `nvim --server "$NVIM" --remote-send` (see .config/lazygit/config.yml).
    init = function()
      local function open_file_diff(file)
        if not file or file == "" then
          vim.notify("Usage: :CodeDiffFile <path>", vim.log.levels.ERROR)
          return
        end
        vim.cmd.edit(vim.fn.fnameescape(file))
        vim.cmd.CodeDiff()
      end
      _G.CodeDiffFile = open_file_diff
      vim.api.nvim_create_user_command("CodeDiffFile", function(cmd_opts)
        open_file_diff(cmd_opts.args)
      end, { nargs = 1, complete = "file", desc = "Open CodeDiff explorer focused on <path>" })

      -- Same as CodeDiffFile, but quits LazyGit first via LazyGitQuitThen
      -- (defined in the kdheepak/lazygit.nvim spec) so LazyGit actually
      -- closes instead of sitting hidden behind the diff view.
      _G.LazyGitOpenCodeDiff = function(file)
        _G.LazyGitQuitThen(function()
          open_file_diff(file)
        end)
      end
    end,
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
