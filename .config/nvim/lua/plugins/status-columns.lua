return {
  "luukvbaal/statuscol.nvim",
  config = function()
    local builtin = require('statuscol.builtin')
    require("statuscol").setup({
      bt_ignore = { 'terminal', 'nofile', 'ddu-ff', 'ddu-ff-filter' },
      relculright = true,
      segments = {
        {
          sign = {
            namespace = { 'diagnostic' },
            maxwidth = 1,
          },
        },
        {
          text = { builtin.lnumfunc },
        },
        { text = { ' ' } },
        {
          sign = {
            namespace = { 'gitsigns' },
            maxwidth = 1,
            colwidth = 1,
            wrap = true,
          },
        },
        { text = { '│' } },
      },
    })
  end,
}
