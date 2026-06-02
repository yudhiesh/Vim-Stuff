local M = {}

local commands_created = false

local function path_exists(path)
  return path and vim.uv.fs_stat(path) ~= nil
end

local function project_root(path)
  local current = path
  if not current or current == "" then
    current = vim.api.nvim_buf_get_name(0)
  end

  local start = current ~= "" and vim.fs.dirname(current) or vim.uv.cwd()
  local root = vim.fs.find({ "pixi.toml", "Justfile", ".clangd", ".git" }, {
    path = start,
    upward = true,
  })[1]

  return root and vim.fs.dirname(root) or vim.uv.cwd()
end

local function relative_to_root(path, root)
  if not path or path == "" then
    return nil
  end

  local prefix = root .. "/"
  if vim.startswith(path, prefix) then
    return path:sub(#prefix + 1)
  end

  return path
end

local function current_kernel_name()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    return nil
  end

  local stem = vim.fn.fnamemodify(path, ":t:r")
  if stem == "" then
    return nil
  end

  return (stem:gsub("^test_", ""))
end

local function current_test_file()
  local root = project_root()
  local current = vim.api.nvim_buf_get_name(0)
  local rel = relative_to_root(current, root)

  if rel and rel:match("^tests/test_.+%.py$") then
    return current
  end

  local kernel = current_kernel_name()
  if not kernel then
    return nil
  end

  local test_path = vim.fs.joinpath(root, "tests", "test_" .. kernel .. ".py")
  return path_exists(test_path) and test_path or nil
end

local function open_terminal(cmd)
  local root = project_root()
  vim.cmd("botright 15split")
  vim.fn.termopen({ "bash", "-lc", cmd }, { cwd = root })
  vim.cmd("startinsert")
end

local function run_repo_command(cmd)
  open_terminal(cmd)
end

function M.run_current_test()
  local root = project_root()
  local test_file = current_test_file()
  if test_file then
    run_repo_command("just test-cuda " .. vim.fn.shellescape(relative_to_root(test_file, root)))
    return
  end

  local kernel = current_kernel_name()
  if kernel then
    run_repo_command("just test-cuda -- -k " .. vim.fn.shellescape(kernel))
    return
  end

  vim.notify("Could not determine the CUDA kernel test for this buffer", vim.log.levels.WARN)
end

function M.run_all_tests()
  run_repo_command("just test-all")
end

function M.verify_hardware()
  run_repo_command("just verify-hw")
end

function M.debug_current_test()
  local root = project_root()
  local test_file = current_test_file()
  if not test_file then
    vim.notify("Open a CUDA source or matching pytest file first", vim.log.levels.WARN)
    return
  end

  local python = vim.fs.joinpath(root, ".pixi", "envs", "benchmark", "bin", "python")
  if not path_exists(python) then
    python = "python"
  end

  local rel_test = relative_to_root(test_file, root)
  local cmd = table.concat({
    "CUDA_LAUNCH_BLOCKING=1",
    "cuda-gdb --args",
    vim.fn.shellescape(python),
    "-m pytest -q",
    vim.fn.shellescape(rel_test),
  }, " ")

  run_repo_command(cmd)
end

function M.open_alternate()
  local root = project_root()
  local current = vim.api.nvim_buf_get_name(0)
  if current == "" then
    vim.notify("Open a CUDA or pytest file first", vim.log.levels.WARN)
    return
  end

  local kernel = current_kernel_name()
  if not kernel then
    vim.notify("Could not determine the current kernel name", vim.log.levels.WARN)
    return
  end

  local rel = relative_to_root(current, root)
  local candidates = {}

  local function add(path)
    if path ~= current and path_exists(path) then
      candidates[#candidates + 1] = path
    end
  end

  if rel and rel:match("^cuda/test_.+%.cu$") then
    add(vim.fs.joinpath(root, "cuda", kernel .. ".cuh"))
    add(vim.fs.joinpath(root, "tests", "test_" .. kernel .. ".py"))
  elseif rel and rel:match("^cuda/.+%.cuh$") then
    add(vim.fs.joinpath(root, "cuda", "test_" .. kernel .. ".cu"))
    add(vim.fs.joinpath(root, "tests", "test_" .. kernel .. ".py"))
  elseif rel and rel:match("^tests/test_.+%.py$") then
    add(vim.fs.joinpath(root, "cuda", kernel .. ".cuh"))
    add(vim.fs.joinpath(root, "cuda", "test_" .. kernel .. ".cu"))
  end

  if #candidates == 0 then
    vim.notify("No alternate CUDA file found", vim.log.levels.INFO)
    return
  end

  if #candidates == 1 then
    vim.cmd.edit(vim.fn.fnameescape(candidates[1]))
    return
  end

  vim.ui.select(candidates, {
    prompt = "Open related CUDA file",
    format_item = function(item)
      return relative_to_root(item, root)
    end,
  }, function(choice)
    if choice then
      vim.cmd.edit(vim.fn.fnameescape(choice))
    end
  end)
end

function M.setup()
  if commands_created then
    return
  end

  commands_created = true

  vim.api.nvim_create_user_command("CudaAlternate", M.open_alternate, {
    desc = "Open the related CUDA or pytest file",
  })
  vim.api.nvim_create_user_command("CudaDebugCurrent", M.debug_current_test, {
    desc = "Debug the current CUDA test with cuda-gdb",
  })
  vim.api.nvim_create_user_command("CudaTestAll", M.run_all_tests, {
    desc = "Run the full CUDA pytest suite",
  })
  vim.api.nvim_create_user_command("CudaTestCurrent", M.run_current_test, {
    desc = "Run the CUDA pytest for the current kernel",
  })
  vim.api.nvim_create_user_command("CudaVerifyHw", M.verify_hardware, {
    desc = "Run the CUDA hardware verification helper",
  })
end

return M
