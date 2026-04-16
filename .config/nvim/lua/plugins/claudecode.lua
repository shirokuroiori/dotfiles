return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    config = true,
    keys = {
      { "<leader>a",   nil,                 desc = "AI/Claude Code" },
      { "<C-\\><C-n>", "<C-\\><C-n>",       mode = "t",             desc = "Exit terminal mode" },
      { "<C-h>",       "<C-\\><C-n><C-w>h", mode = "t",             desc = "Move to left window" },
      { "<C-l>",       "<C-\\><C-n><C-w>l", mode = "t",             desc = "Move to right window" },
      { -- aiueo
        "<leader>aR",
        function()
          local buf = vim.api.nvim_get_current_buf()
          local chan = vim.bo[buf].channel
          if chan and chan > 0 then
            local pid = vim.fn.jobpid(chan)
            vim.fn.system("kill -WINCH " .. pid)
            vim.cmd("redraw!")
          end
        end,
        desc = "Redraw Claude (SIGWINCH)",
      },
      { "<leader>ac", "<cmd>ClaudeCode<cr>",            desc = "Toggle Claude" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>",       desc = "Focus Claude" },
      { "<leader>ar", "<cmd>ClaudeCode --resume<cr>",   desc = "Resume Claude" },
      { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
      { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>",       desc = "Add current buffer" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>",        mode = "v",                  desc = "Send to Claude" },
      {
        "<leader>as",
        "<cmd>ClaudeCodeTreeAdd<cr>",
        desc = "Add file",
        ft = { "NvimTree", "neo-tree", "oil", "minifiles" },
      },
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>",   desc = "Deny diff" },
    },
  },
}
