return {
  'NeogitOrg/neogit',
  dependencies = {
    'nvim-lua/plenary.nvim', -- required

    -- Only one of these is needed, not both.
    'nvim-telescope/telescope.nvim', -- optional
  },
  config = function()
    local neogit = require 'neogit'
    neogit.setup {}
    vim.keymap.set('n', '<leader>gs', '<cmd>Neogit<CR>', { desc = 'Open Neogit' })
  end,
}
