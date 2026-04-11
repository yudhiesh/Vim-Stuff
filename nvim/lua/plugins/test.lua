local python_roots = {}
local python_roots_loaded = false
local python_roots_file = vim.fs.joinpath(vim.fn.stdpath("state"), "neotest-python-roots.json")

local function path_exists(path)
  return path and vim.uv.fs_stat(path) ~= nil
end

local function load_python_roots()
  if python_roots_loaded then
    return
  end

  python_roots_loaded = true

  if vim.fn.filereadable(python_roots_file) == 0 then
    return
  end

  local content = table.concat(vim.fn.readfile(python_roots_file), "\n")
  if content == "" then
    return
  end

  local ok, decoded = pcall(vim.json.decode, content)
  if ok and type(decoded) == "table" then
    python_roots = decoded
  end
end

local function save_python_roots()
  vim.fn.mkdir(vim.fn.stdpath("state"), "p")
  vim.fn.writefile({ vim.json.encode(python_roots) }, python_roots_file)
end

local function python_project_root()
  local bufname = vim.api.nvim_buf_get_name(0)
  local start = bufname ~= "" and vim.fs.dirname(bufname) or vim.uv.cwd()
  local root_file = vim.fs.find({
    "pyproject.toml",
    "pytest.ini",
    "setup.cfg",
    "setup.py",
    "requirements.txt",
    ".git",
  }, { path = start, upward = true })[1]

  return root_file and vim.fs.dirname(root_file) or vim.uv.cwd()
end

local function python_candidates(root)
  local candidates = {}
  local seen = {}

  local function add(path, label)
    if not path_exists(path) or seen[path] then
      return
    end
    seen[path] = true
    candidates[#candidates + 1] = { path = path, label = label }
  end

  if vim.env.VIRTUAL_ENV then
    add(vim.fs.joinpath(vim.env.VIRTUAL_ENV, "bin", "python"), "active shell venv")
  end

  add(vim.fs.joinpath(root, ".venv", "bin", "python"), ".venv")
  add(vim.fs.joinpath(root, "venv", "bin", "python"), "venv")
  add(vim.fs.joinpath(root, "env", "bin", "python"), "env")
  add(vim.fs.joinpath(root, ".pixi", "envs", "default", "bin", "python"), "pixi default")

  return candidates
end

local function current_python()
  load_python_roots()

  local root = python_project_root()
  local selected = python_roots[root]

  if path_exists(selected) then
    return selected
  end

  local candidates = python_candidates(root)
  return candidates[1] and candidates[1].path or nil
end

local function select_python()
  load_python_roots()

  local root = python_project_root()
  local candidates = python_candidates(root)

  if #candidates == 0 then
    vim.notify(
      "No Python virtualenv found for " .. root .. ". Create one in .venv/, venv/, or env/ first.",
      vim.log.levels.WARN,
      { title = "Neotest Python" }
    )
    return
  end

  vim.ui.select(candidates, {
    prompt = "Select Python interpreter",
    format_item = function(item)
      return string.format("%s -> %s", item.label, item.path)
    end,
  }, function(choice)
    if not choice then
      return
    end

    python_roots[root] = choice.path
    save_python_roots()
    vim.notify("Using " .. choice.path .. " for " .. root, vim.log.levels.INFO, { title = "Neotest Python" })
  end)
end

return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/neotest-python",
    },
    init = function()
      vim.api.nvim_create_user_command("PythonSelectVenv", select_python, {
        desc = "Select Python interpreter for neotest",
      })
    end,
    keys = {
      { "<leader>cv", select_python, desc = "Select VirtualEnv", ft = "python" },
    },
    opts = {
      adapters = {
        ["neotest-python"] = {
          python = current_python,
        },
      },
    },
  },
}
