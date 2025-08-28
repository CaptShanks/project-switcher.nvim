-- Project switcher for git repositories
-- Allows switching between different git repos without changing tmux panes

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
              display = string.format("%-30s %s", project_name, project_dir)
            })
          end
        end
      end
    end
  end

  -- Sort projects by name
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

-- Get all projects (from cache or fresh search)
function M.get_projects(force_refresh)
  if not force_refresh then
    local cached = load_cache()
    if next(cached) then
      return cached
    end
  end

  local projects = find_git_repos(M.config.search_dirs, M.config.max_depth, M.config.show_hidden)
  save_cache(projects)
  return projects
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

-- Show project picker using vim.ui.select (safer approach)
function M.pick_project()
  local projects = M.get_projects()
  
  if #projects == 0 then
    vim.notify("No git repositories found in configured directories", vim.log.levels.WARN)
    return
  end
  
  -- Create a simple list for vim.ui.select
  local choices = {}
  for i, project in ipairs(projects) do
    choices[i] = project.name .. " → " .. project.path
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

  -- Create user commands
  vim.api.nvim_create_user_command("ProjectSwitch", M.pick_project, {
    desc = "Switch to a different git repository project"
  })

  vim.api.nvim_create_user_command("ProjectRefresh", M.refresh_projects, {
    desc = "Refresh the projects cache"
  })
end

return M