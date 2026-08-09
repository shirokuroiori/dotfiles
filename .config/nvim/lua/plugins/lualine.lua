return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  dependencies = { "DaikyXendo/nvim-material-icon" },
  init = function()
    vim.o.laststatus = 0
    vim.o.showtabline = 0
  end,
  opts = function()
    local p = require('voltwave.palette')

    local save_flash_until = 0
    vim.api.nvim_create_autocmd('BufWritePost', {
      group = vim.api.nvim_create_augroup('lualine_save_flash', { clear = true }),
      callback = function()
        save_flash_until = (vim.uv or vim.loop).hrtime() + 0.8 * 1e9
        require('lualine').refresh()
        vim.defer_fn(function()
          require('lualine').refresh()
        end, 800)
      end,
    })

    local lsp_error_active = false
    local orig_show_message = vim.lsp.handlers['window/showMessage']
    vim.lsp.handlers['window/showMessage'] = function(err, result, ctx, config)
      if result and result.type == vim.lsp.protocol.MessageType.Error then
        lsp_error_active = true
        require('lualine').refresh()
      end
      if orig_show_message then
        orig_show_message(err, result, ctx, config)
      end
    end
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('lualine_lsp_error_clear', { clear = true }),
      callback = function()
        if lsp_error_active then
          lsp_error_active = false
          require('lualine').refresh()
        end
      end,
    })

    -- starship.toml-style granular git status (untracked/modified/staged/deleted/renamed/conflicted/ahead-behind)
    local GIT_STATUS_STYLE = {
      { key = 'untracked',  icon = '',  color = '#00fc65' },
      { key = 'modified',   icon = '󱇨', color = '#27d7e8' },
      { key = 'staged',     icon = '󱇧', color = '#27d7e8' },
      { key = 'deleted',    icon = '󱀷', color = '#FF4D4D' },
      { key = 'renamed',    icon = '󰁕', color = p.purple },
      { key = 'ahead',      icon = '',  color = p.purple },
      { key = 'behind',     icon = '',  color = p.purple },
    }
    local git_status = { untracked = 0, modified = 0, staged = 0, deleted = 0, renamed = 0, conflicted = 0, ahead = 0, behind = 0 }

    local function refresh_git_status()
      vim.system({ 'git', 'status', '--porcelain=v2', '--branch' }, { cwd = vim.fn.getcwd(), text = true }, function(res)
        local s = { untracked = 0, modified = 0, staged = 0, deleted = 0, renamed = 0, conflicted = 0, ahead = 0, behind = 0 }
        if res.code == 0 and res.stdout then
          for line in res.stdout:gmatch('[^\n]+') do
            if line:sub(1, 12) == '# branch.ab ' then
              local ahead, behind = line:match('# branch%.ab %+(%d+) %-(%d+)')
              s.ahead = tonumber(ahead) or 0
              s.behind = tonumber(behind) or 0
            elseif line:sub(1, 2) == '1 ' or line:sub(1, 2) == '2 ' then
              local x, y = line:match('^%d ([%.%a])([%.%a])')
              if x and x ~= '.' then
                s.staged = s.staged + 1
              end
              if y == 'M' then
                s.modified = s.modified + 1
              end
              if y == 'D' or x == 'D' then
                s.deleted = s.deleted + 1
              end
              if line:sub(1, 2) == '2 ' then
                s.renamed = s.renamed + 1
              end
            elseif line:sub(1, 2) == 'u ' then
              s.conflicted = s.conflicted + 1
            elseif line:sub(1, 2) == '? ' then
              s.untracked = s.untracked + 1
            end
          end
        end
        vim.schedule(function()
          git_status = s
          require('lualine').refresh()
        end)
      end)
    end
    vim.api.nvim_create_autocmd({ 'BufWritePost', 'FocusGained', 'DirChanged' }, {
      group = vim.api.nvim_create_augroup('lualine_git_status', { clear = true }),
      callback = refresh_git_status,
    })
    vim.defer_fn(refresh_git_status, 500)
    ;(vim.uv or vim.loop).new_timer():start(10000, 10000, vim.schedule_wrap(refresh_git_status))

    return {
      options = {
        icons_enabled = true,
        theme = require('voltwave.extras.lualine').get(),
        always_show_tabline = true,
        globalstatus = true,
        section_separators = { left = '▓▒░', right = '░▒▓' },
        component_separators = { left = '', right = '' },
      },
      sections = {
        lualine_a = {
          {
            'mode',
            fmt = function(mode)
              local icon = ({
                NORMAL = '▶',
                INSERT = '✎',
                VISUAL = '⛶',
                ['V-LINE'] = '󰘤',
                ['V-BLOCK'] = '▦',
                REPLACE = '⇄',
                COMMAND = '',
                TERMINAL = '',
              })[mode]
              return icon and (icon .. ' ' .. mode) or mode
            end,
          },
        },
        lualine_b = {
          'branch',
          {
            'diff',
            symbols = { added = ' ', modified = ' ', removed = ' ' },
          },
          {
            function()
              local s = git_status
              local segs = {}
              for _, st in ipairs(GIT_STATUS_STYLE) do
                if st.key ~= 'ahead' and st.key ~= 'behind' and s[st.key] > 0 then
                  table.insert(segs, st.icon .. ' ' .. s[st.key])
                end
              end
              if s.conflicted > 0 then
                table.insert(segs, '⇕')
              end
              local out = table.concat(segs, ' ')
              if s.ahead > 0 or s.behind > 0 then
                local ab = {}
                if s.ahead > 0 then
                  table.insert(ab, ' ' .. s.ahead)
                end
                if s.behind > 0 then
                  table.insert(ab, ' ' .. s.behind)
                end
                out = (out ~= '' and (out .. ' │ ') or '') .. table.concat(ab, ' ')
              end
              if out == '' then
                return ''
              end
              return '│ ' .. out
            end,
            fmt = function(str, ctx)
              if str == '' then
                return str
              end
              local off = ctx:get_default_hl()
              ctx._gs_sep = ctx._gs_sep or ctx:create_hl({ fg = p.fg_dim }, 'sep')
              local sep_on = ctx:format_hl(ctx._gs_sep)
              str = str:gsub('^│', function(m) return sep_on .. m .. off end)
              for _, st in ipairs(GIT_STATUS_STYLE) do
                local hl_key = '_gs_' .. st.key
                ctx[hl_key] = ctx[hl_key] or ctx:create_hl({ fg = st.color }, st.key)
                local on = ctx:format_hl(ctx[hl_key])
                str = str:gsub('(' .. st.icon .. ' %d+)', function(m) return on .. m .. off end)
              end
              ctx._gs_conflicted = ctx._gs_conflicted or ctx:create_hl({ fg = p.purple }, 'conflicted')
              local conflict_on = ctx:format_hl(ctx._gs_conflicted)
              str = str:gsub('⇕', function(m) return conflict_on .. m .. off end)
              return str
            end,
          },
        },
        lualine_c = {
          {
            function()
              local total = 0
              for _, n in pairs(vim.diagnostic.count(0)) do
                total = total + n
              end
              if total == 0 then
                return '★ VICTORY'
              end
              local width = 8
              local filled = math.min(total, width)
              return 'BOSS ' .. string.rep('▓', filled) .. string.rep('░', width - filled)
            end,
            fmt = function(str, ctx)
              ctx._boss_hl = ctx._boss_hl or ctx:create_hl({ fg = p.error }, 'boss')
              local hl_on, hl_off = ctx:format_hl(ctx._boss_hl), ctx:get_default_hl()
              return (str:gsub('▓+', function(m) return hl_on .. m .. hl_off end))
            end,
          },
          {
            function()
              if lsp_error_active then
                return '⚠ LSP ERROR'
              end
              if #vim.lsp.get_clients({ bufnr = 0 }) == 0 then
                return '󰊠 NO LSP'
              end
              return ''
            end,
            fmt = function(str, ctx)
              if str == '' then
                return str
              end
              if str:find('ERROR') then
                ctx._lsp_err_hl = ctx._lsp_err_hl or ctx:create_hl({ fg = p.error }, 'lsp_err')
                return ctx:format_hl(ctx._lsp_err_hl) .. str .. ctx:get_default_hl()
              end
              ctx._no_lsp_hl = ctx._no_lsp_hl or ctx:create_hl({ fg = p.fg_dim }, 'no_lsp')
              return ctx:format_hl(ctx._no_lsp_hl) .. str .. ctx:get_default_hl()
            end,
          },
          {
            'lsp_status',
            icon = '', -- f013
            symbols = {
              -- Classic ASCII spinner while LSP is busy (unambiguous at a glance):
              spinner = { '|', '/', '-', '\\' },
              -- Standard unicode symbol for when LSP is done:
              done = '󱪙 ',
              -- Delimiter inserted between LSP names:
              separator = ' ',
            },
            -- List of LSP names to ignore (e.g., `null-ls`):
            ignore_lsp = {},
            fmt = function(str, ctx)
              ctx._done_hl = ctx._done_hl or ctx:create_hl({ fg = p.green }, 'done')
              ctx._busy_hl = ctx._busy_hl or ctx:create_hl({ fg = p.yellow }, 'busy')
              local done_on, off = ctx:format_hl(ctx._done_hl), ctx:get_default_hl()
              local busy_on = ctx:format_hl(ctx._busy_hl)
              -- Some servers (e.g. tailwindcss-language-server) never emit $/progress,
              -- so lualine's built-in state never learns they're "done". Treat a client
              -- that has never reported progress as immediately ready.
              for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
                if ctx.lsp_work_by_client_id[client.id] == nil then
                  local s, e = str:find(client.name, 1, true)
                  if s then
                    str = str:sub(1, e) .. ' 󱪙' .. str:sub(e + 1)
                  end
                end
              end
              str = str:gsub('󱪙', function(icon) return done_on .. icon .. off end)
              str = str:gsub('[|/%-\\]+', function(spin) return busy_on .. 'LOADING ' .. spin .. off end)
              return str
            end,
          },
        },
        lualine_y = {
          'location',
          {
            function()
              local cur, last = vim.fn.line('.'), vim.fn.line('$')
              local ratio = cur / math.max(last, 1)
              local width = 8
              local filled = math.floor(ratio * width + 0.5)
              return 'EXP ' .. string.rep('█', filled) .. string.rep('░', width - filled)
            end,
            fmt = function(str, ctx)
              ctx._exp_hl = ctx._exp_hl or ctx:create_hl({ fg = p.green_bolt }, 'exp')
              local hl_on, hl_off = ctx:format_hl(ctx._exp_hl), ctx:get_default_hl()
              return (str:gsub('█+', function(filled) return hl_on .. filled .. hl_off end))
            end,
          },
        },
        lualine_z = {
          function()
            if (vim.uv or vim.loop).hrtime() < save_flash_until then
              return '★ SAVED'
            end
            return "  " .. os.date("%R")
          end,
        },
      },
    }
  end,
}
