-- Project Switcher Plugin Entry Point
-- This file is loaded automatically by Neovim when the plugin is installed

if vim.g.loaded_project_switcher then
  return
end
vim.g.loaded_project_switcher = true

-- Set up default keymaps if not configured elsewhere
if not vim.g.project_switcher_no_default_keymaps then
  vim.keymap.set('n', '<leader>fp', function()
    require('project-switcher').pick_project()
  end, { desc = 'Switch Project' })
  
  vim.keymap.set('n', '<leader>fP', function()
    require('project-switcher').refresh_projects()
  end, { desc = 'Refresh Projects' })
end