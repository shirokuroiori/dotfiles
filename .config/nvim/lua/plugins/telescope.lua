local function live_grep_with_toggles()
  local flags = { regex = false, case_sensitive = false, word = false }

  local function make_title()
    local active = {}
    if flags.regex then table.insert(active, "regex") end
    if flags.case_sensitive then table.insert(active, "case") end
    if flags.word then table.insert(active, "word") end
    local title = "Live Grep"
    if #active > 0 then title = title .. " [" .. table.concat(active, ",") .. "]" end
    return title .. "  (M-r:regex  M-c:case  M-w:word)"
  end

  local function run(current_input)
    require("telescope.builtin").live_grep({
      prompt_title = make_title(),
      default_text = current_input or "",
      additional_args = function()
        local args = {}
        if flags.regex then table.insert(args, "--pcre2") else table.insert(args, "--fixed-strings") end
        if flags.case_sensitive then table.insert(args, "--case-sensitive") end
        if flags.word then table.insert(args, "--word-regexp") end
        return args
      end,
      attach_mappings = function(_, map)
        local function toggle(flag)
          return function(prompt_bufnr)
            flags[flag] = not flags[flag]
            local input = require("telescope.actions.state").get_current_line()
            require("telescope.actions").close(prompt_bufnr)
            vim.schedule(function() run(input) end)
          end
        end
        map("i", "<M-r>", toggle("regex"))
        map("i", "<M-c>", toggle("case_sensitive"))
        map("i", "<M-w>", toggle("word"))
        map("n", "<M-r>", toggle("regex"))
        map("n", "<M-c>", toggle("case_sensitive"))
        map("n", "<M-w>", toggle("word"))
        return true
      end,
    })
  end

  run()
end

return {
  "nvim-telescope/telescope.nvim",
  version = "0.1.x",
  dependencies = { "nvim-lua/plenary.nvim" },
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<CR>",  desc = "Find files" },
    { "<leader>fg", live_grep_with_toggles,           desc = "Live grep" },
    { "<leader>fb", "<cmd>Telescope buffers<CR>",     desc = "Buffers" },
    { "<leader>fr", "<cmd>Telescope oldfiles<CR>",    desc = "Recent files" },
  },
}
