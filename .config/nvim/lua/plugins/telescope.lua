local function live_grep_with_toggles(glob)
  local flags = { regex = false, case_sensitive = false, word = false }

  local function make_title()
    local active = {}
    if flags.regex then table.insert(active, "regex") end
    if flags.case_sensitive then table.insert(active, "case") end
    if flags.word then table.insert(active, "word") end
    local title = glob and ("Live Grep [" .. glob .. "]") or "Live Grep"
    if #active > 0 then title = title .. " [" .. table.concat(active, ",") .. "]" end
    return title .. "  (M-r:regex  M-c:case  M-w:word)"
  end

  local function run(current_input)
    require("telescope.builtin").live_grep({
      prompt_title = make_title(),
      default_text = current_input or "",
      glob_pattern = glob and (glob:sub(1, 1) == "!" and ("!*" .. glob:sub(2) .. "*") or ("*" .. glob .. "*")) or nil,
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

local function live_grep_by_glob()
  local pattern = vim.fn.input("File glob (! to exclude): ")
  if pattern == "" then return end
  live_grep_with_toggles(pattern)
end

local function find_files_by_glob()
  local pattern = vim.fn.input("Glob pattern (! to exclude): ")
  if pattern == "" then return end
  local exclude = pattern:sub(1, 1) == "!"
  local raw = exclude and pattern:sub(2) or pattern
  require("telescope.builtin").find_files({
    prompt_title = (exclude and "Files: exclude *" or "Files: *") .. raw .. "*",
    find_command = exclude
      and { "fd", "--type", "f", "--exclude", "*" .. raw .. "*" }
      or  { "fd", "--type", "f", "--glob",    "*" .. raw .. "*" },
  })
end

return {
  "nvim-telescope/telescope.nvim",
  version = "0.1.x",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    defaults = {
      path_display = { "smart" },
      file_ignore_patterns = { "%.git/" },
      mappings = {
        i = {
          ["<C-y>"] = function(prompt_bufnr)
            local entry = require("telescope.actions.state").get_selected_entry()
            local path = entry and (entry.path or entry.filename or entry.value)
            if path then print(path) end
          end,
        },
        n = {
          ["<C-y>"] = function(prompt_bufnr)
            local entry = require("telescope.actions.state").get_selected_entry()
            local path = entry and (entry.path or entry.filename or entry.value)
            if path then print(path) end
          end,
        },
      },
    },
  },
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<CR>",  desc = "Find files" },
    { "<leader>fp", find_files_by_glob,               desc = "Find files by glob pattern" },
    { "<leader>fg", live_grep_with_toggles,           desc = "Live grep" },
    { "<leader>fG", live_grep_by_glob,                desc = "Live grep with file glob" },
    { "<leader>fb", "<cmd>Telescope buffers<CR>",     desc = "Buffers" },
    { "<leader>fr", "<cmd>Telescope oldfiles<CR>",    desc = "Recent files" },
    {
      "<leader>fc",
      function()
        require("telescope.builtin").find_files({
          prompt_title = "Find files (.config)",
          hidden = true,
          search_dirs = { vim.fn.expand("$HOME/dotfiles/.config") },
        })
      end,
      desc = "Find files in .config",
    },
    {
      "<leader>fC",
      function()
        require("telescope.builtin").live_grep({
          prompt_title = "Live grep (.config)",
          additional_args = { "--hidden" },
          search_dirs = { vim.fn.expand("$HOME/dotfiles/.config") },
        })
      end,
      desc = "Live grep in .config",
    },
  },
}
