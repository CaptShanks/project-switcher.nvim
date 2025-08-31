-- Project switcher for git repositories and custom folders
-- Allows switching between different projects without changing tmux panes

local M = {}

-- Default configuration
M.config = {
  -- Directories to search for git repos
  search_dirs = {
    "~/",
    "~/Documents/git",
    "~/code",
    "~/work",
    "~/dev",
    "~/dotfiles",
  },
  -- Additional folders to include (both git and non-git)
  additional_folders = {
    -- Example:
    -- "~/my-important-project",
    -- "~/Documents/notes",
    -- "/path/to/any/folder",
  },
  -- Maximum depth to search for git repos
  max_depth = 3,
  -- Show hidden directories (starting with .)
  show_hidden = false,
  -- Cache projects for faster loading
  use_cache = true,
  cache_file = vim.fn.stdpath("state") .. "/projects_cache.json",
}

-- Cache for found projects
local projects_cache = {}
local cache_loaded = false

-- Find git repositories in given directories
local function find_git_repos(dirs, max_depth, show_hidden)
  local projects = {}
  local seen = {}

  for _, dir in ipairs(dirs) do
    local expanded_dir = vim.fn.expand(dir)
    if vim.fn.isdirectory(expanded_dir) == 1 then
      local find_cmd = {
        "find",
        expanded_dir,
        "-maxdepth", tostring(max_depth),
        "-type", "d",
        "-name", ".git"
      }

      local result = vim.fn.system(find_cmd)

      if vim.v.shell_error == 0 then
        for line in result:gmatch("[^\r\n]+") do
          local project_dir = line:gsub("/.git$", "")
          local project_name = vim.fn.fnamemodify(project_dir, ":t")

          -- Skip if we've seen this project or if it's hidden and we don't want hidden
          if not seen[project_dir] and (show_hidden or not project_name:match("^%.")) then
            seen[project_dir] = true
            table.insert(projects, {
              name = project_name,
              path = project_dir,
              type = "git"
            })
          end
        end
      end
    end
  end

  return projects
end

-- Add additional folders from config
local function add_additional_folders(projects)
  local seen = {}
  
  -- Track existing projects to avoid duplicates
  for _, project in ipairs(projects) do
    seen[project.path] = true
  end
  
  -- Add additional folders
  for _, folder in ipairs(M.config.additional_folders) do
    local expanded_path = vim.fn.expand(folder)
    if vim.fn.isdirectory(expanded_path) == 1 and not seen[expanded_path] then
      seen[expanded_path] = true
      local folder_name = vim.fn.fnamemodify(expanded_path, ":t")
      table.insert(projects, {
        name = folder_name,
        path = expanded_path,
        type = "custom"
      })
    end
  end
  
  -- Sort all projects by name
  table.sort(projects, function(a, b) return a.name < b.name end)
  
  return projects
end

-- Load projects from cache
local function load_cache()
  if cache_loaded then return projects_cache end
  cache_loaded = true

  if not M.config.use_cache then return {} end

  local cache_file = M.config.cache_file
  if vim.fn.filereadable(cache_file) == 1 then
    local ok, content = pcall(vim.fn.readfile, cache_file)
    if ok and content then
      local cache_str = table.concat(content, "\n")
      local ok_decode, decoded = pcall(vim.fn.json_decode, cache_str)
      if ok_decode and decoded and decoded.projects then
        projects_cache = decoded.projects
      end
    end
  end

  return projects_cache
end

-- Save projects to cache
local function save_cache(projects)
  if not M.config.use_cache then return end

  projects_cache = projects
  local cache_data = {
    timestamp = os.time(),
    projects = projects
  }

  local ok_encode, cache_str = pcall(vim.fn.json_encode, cache_data)
  if ok_encode then
    local ok_write, _ = pcall(vim.fn.writefile, {cache_str}, M.config.cache_file)
    if not ok_write then
      vim.notify("Failed to save projects cache", vim.log.levels.WARN)
    end
  end
end

-- Get all projects (git repos + additional folders)
function M.get_projects(force_refresh)
  local git_projects = {}
  
  if not force_refresh then
    local cached = load_cache()
    if next(cached) then
      git_projects = cached
    end
  end
  
  if #git_projects == 0 then
    git_projects = find_git_repos(M.config.search_dirs, M.config.max_depth, M.config.show_hidden)
    save_cache(git_projects)
  end

  -- Add additional folders from config
  local all_projects = add_additional_folders(git_projects)
  
  return all_projects
end

-- Switch to a project
function M.switch_to_project(project_path)
  if not project_path then return end

  -- Change to the project directory
  local ok, err = pcall(vim.cmd.cd, project_path)
  if not ok then
    vim.notify("Failed to change directory to " .. project_path .. ": " .. (err or "unknown error"), vim.log.levels.ERROR)
    return
  end

  -- Update the working directory
  vim.g.project_root = project_path

  vim.notify("Switched to project: " .. vim.fn.fnamemodify(project_path, ":t"), vim.log.levels.INFO)

  -- Trigger an autocmd for other plugins that might want to know about project switches
  vim.api.nvim_exec_autocmds("User", { pattern = "ProjectSwitched", data = project_path })
end

-- Show project picker using vim.ui.select
function M.pick_project()
  local projects = M.get_projects()
  
  if #projects == 0 then
    vim.notify("No projects found in configured directories", vim.log.levels.WARN)
    return
  end
  
  -- Create a list for vim.ui.select with type indicators
  local choices = {}
  for i, project in ipairs(projects) do
    local type_indicator = project.type == "git" and "🔷" or "📁"
    choices[i] = type_indicator .. " " .. project.name .. " → " .. project.path
  end
  
  vim.ui.select(choices, {
    prompt = "Switch to project:",
  }, function(choice, idx)
    if choice and idx and projects[idx] then
      M.switch_to_project(projects[idx].path)
    end
  end)
end

-- Refresh project cache
function M.refresh_projects()
  cache_loaded = false
  M.get_projects(true)
  vim.notify("Project list refreshed and cached", vim.log.levels.INFO)
end

-- Setup function
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Expand all search directories
  M.config.search_dirs = vim.tbl_map(function(dir)
    return vim.fn.expand(dir)
  end, M.config.search_dirs)

  -- Expand all additional folders
  M.config.additional_folders = vim.tbl_map(function(dir)
    return vim.fn.expand(dir)
  end, M.config.additional_folders)

  -- Create user commands
  vim.api.nvim_create_user_command("ProjectSwitch", M.pick_project, {
    desc = "Switch to a different project"
  })

  vim.api.nvim_create_user_command("ProjectRefresh", M.refresh_projects, {
    desc = "Refresh the projects cache"
  })
end

return M