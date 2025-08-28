# 🚀 Project Switcher.nvim

A Neovim plugin for quickly switching between git repositories without leaving your tmux session.

## ✨ Features

- **Fast project switching** - Jump between git repositories instantly
- **Fuzzy search interface** - Uses `vim.ui.select` (enhanced by pickers like Snacks.nvim)
- **Smart caching** - Caches project list for faster subsequent searches
- **Configurable search paths** - Customize where to look for git repositories
- **No tmux disruption** - Changes Neovim's working directory, keeps tmux panes intact
- **Auto-discovery** - Automatically finds git repositories in configured directories

## 📦 Installation

### With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/project-switcher.nvim",
  lazy = false,
  config = function()
    require("project-switcher").setup({
      -- Customize search directories
      search_dirs = {
        "~/",
        "~/projects",
        "~/code",
        "~/work",
        "~/dev",
        "~/Documents/git",
        -- Add your own directories
      },
      max_depth = 3,
      show_hidden = false,
      use_cache = true,
    })
  end,
  keys = {
    { "<leader>fp", function() require("project-switcher").pick_project() end, desc = "Switch Project" },
    { "<leader>fP", function() require("project-switcher").refresh_projects() end, desc = "Refresh Projects" },
  },
}
```

### With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "your-username/project-switcher.nvim",
  config = function()
    require("project-switcher").setup()
  end
}
```

## ⚙️ Configuration

### Default Configuration

```lua
{
  -- Directories to search for git repositories
  search_dirs = {
    "~/",
    "~/Documents/git",
    "~/code",
    "~/work", 
    "~/dev",
    "~/dotfiles",
  },
  -- Maximum depth to search for git repos
  max_depth = 3,
  -- Show hidden directories (starting with .)
  show_hidden = false,
  -- Cache projects for faster loading
  use_cache = true,
  cache_file = vim.fn.stdpath("state") .. "/projects_cache.json",
}
```

### Custom Configuration Example

```lua
require("project-switcher").setup({
  search_dirs = {
    "~/personal-projects",
    "~/work-projects", 
    "~/opensource",
    "~/Documents/repositories"
  },
  max_depth = 2,
  show_hidden = true, -- Include dotfile repos like .config
  use_cache = true,
})
```

## 🚀 Usage

### Default Keymaps

- `<leader>fp` - Open project picker
- `<leader>fP` - Refresh project cache

### Commands

- `:ProjectSwitch` - Open project picker
- `:ProjectRefresh` - Refresh the projects cache

### Programmatic Usage

```lua
local ps = require("project-switcher")

-- Get all projects
local projects = ps.get_projects()

-- Switch to a specific project
ps.switch_to_project("/path/to/project")

-- Open project picker
ps.pick_project()

-- Force refresh project list
ps.refresh_projects()
```

## 🎯 How It Works

1. **Discovery**: Searches configured directories for `.git` folders
2. **Caching**: Stores found projects for fast subsequent access
3. **Picking**: Uses `vim.ui.select` for project selection (enhanced by picker plugins)
4. **Switching**: Changes Neovim's working directory to selected project
5. **Integration**: Triggers `ProjectSwitched` autocmd for other plugins

## 🔗 Integration

### With Snacks.nvim

Project Switcher works great with [Snacks.nvim](https://github.com/folke/snacks.nvim) picker for enhanced UI:

```lua
{
  "folke/snacks.nvim",
  opts = {
    picker = { enabled = true }
  }
}
```

### Autocmd Integration

Listen for project switches in your config:

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "ProjectSwitched",
  callback = function(ev)
    local project_path = ev.data
    print("Switched to: " .. project_path)
    -- Add your custom logic here
  end,
})
```

## 🤝 Contributing

Contributions welcome! Please feel free to submit a Pull Request.

## 📄 License

MIT License