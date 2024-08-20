return {
  'mfussenegger/nvim-dap',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'rcarriga/nvim-dap-ui',
  },
  config = function()
    local dap, dapui = require 'dap', require 'dapui'

    dapui.setup()

    dap.listeners.before.attach.dapui_config = function()
      dapui.open()
    end
    dap.listeners.before.launch.dapui_config = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated.dapui_config = function()
      dapui.close()
    end
    dap.listeners.before.event_exited.dapui_config = function()
      dapui.close()
    end

    vim.keymap.set('n', '<Leader>db', dap.toggle_breakpoint, {})
    vim.keymap.set('n', '<F5>', dap.continue, {})
    vim.keymap.set('n', '<F10>', dap.step_over, {})
    vim.keymap.set('n', '<F11>', dap.step_into, {})
    vim.keymap.set('n', '<F12>', dap.step_out, {})
    vim.keymap.set('n', '<Leader>de', dapui.eval, {})

    vim.api.nvim_set_hl(0, 'DapBreakpoint', { ctermbg = 0, fg = '#993939', bg = '#31353f' })
    vim.api.nvim_set_hl(0, 'DapLogPoint', { ctermbg = 0, fg = '#61afef', bg = '#31353f' })
    vim.api.nvim_set_hl(0, 'DapStopped', { ctermbg = 0, fg = '#98c379', bg = '#31353f' })

    vim.fn.sign_define('DapBreakpoint', { text = '', texthl = 'DapBreakpoint', linehl = 'DapBreakpoint', numhl = 'DapBreakpoint' })
    vim.fn.sign_define('DapLogPoint', { text = '', texthl = 'DapLogPoint', linehl = 'DapLogPoint', numhl = 'DapLogPoint' })
    vim.fn.sign_define('DapStopped', { text = '', texthl = 'DapStopped', linehl = 'DapStopped', numhl = 'DapStopped' })

    local function find_launchsettings_files()
      local cwd = vim.fn.getcwd() -- Get the current working directory
      local launchsettings_files = {} -- Table to store found files

      local function scan_directory(dir)
        local handle = vim.loop.fs_scandir(dir)
        if handle then
          while true do
            local name, type = vim.loop.fs_scandir_next(handle)
            if not name then
              break
            end

            local full_path = dir .. '/' .. name
            vim.api.nvim_out_write(full_path)
            if type == 'directory' then
              scan_directory(full_path)
            elseif type == 'file' and name == 'launchSettings.json' then
              table.insert(launchsettings_files, full_path)
            end
          end
        end
      end

      -- Start scanning from the current working directory
      scan_directory(cwd)

      -- Return the table of found files
      return launchsettings_files
    end

    local function get_parent_directory(file_path)
      return vim.fn.fnamemodify(file_path, ':h')
    end

    -- Function to get the project path by getting the grandparent directory
    local function get_project_path(file_path)
      print(file_path)
      -- Get the parent directory of the file
      local parent_dir = get_parent_directory(file_path)

      -- Get the parent directory of the parent directory (grandparent directory)
      local project_path = get_parent_directory(parent_dir)

      -- Return the project path with a trailing slash
      return project_path
    end

    local function get_assembly_name(csproj_path)
      local file = io.open(csproj_path, 'r')
      if not file then
        print('Could not open file:', csproj_path)
        return nil
      end

      local content = file:read '*a'
      file:close()

      -- Extract the AssemblyName from the .csproj content
      local assembly_name = content:match '<AssemblyName>(.-)</AssemblyName>'
      if assembly_name then
        return assembly_name
      else
        print('AssemblyName not found in', csproj_path)
        return nil
      end
    end

    local function select_launchsettings()
      local files = find_launchsettings_files()
      if #files == 0 then
        vim.api.nvim_err_writeln 'failed to find any launchSettings.json files'
      elseif #files == 1 then
        return files[1]
      else
        local options = {}
        for i = 1, #files do
          table.insert(options, {
            filename = vim.fn.fnamemodify(get_project_path(files[i]), ':t'),
            file = files[i],
          })
        end

        local co = coroutine.running()
        assert(co, 'must be running under a coroutine')

        local result = nil
        vim.ui.select(options, {
          prompt = 'Select a project:',
          format_item = function(item)
            return item.filename
          end,
        }, function(selected)
          result = selected
          coroutine.resume(co, str)
        end)

        coroutine.yield()
        return result.file
      end
    end

    local function select_profile(launch_settings_file)
      local file_contents = vim.fn.readfile(launch_settings_file)
      local json_data = vim.fn.json_decode(file_contents)

      local profile_count = 0
      local data = nil
      for profile_name, profile_data in pairs(json_data.profiles) do
        print(profile_name)
        profile_count = profile_count + 1
        data = profile_data
      end

      if profile_count == 1 then
        return data
      end

      print(vim.inspect(profiles))

      local options = {}
      for profile_name, profile_data in pairs(json_data.profiles) do
        table.insert(options, {
          name = profile_name,
          profile = profile_data,
        })
      end

      local co = coroutine.running()
      assert(co, 'must be running under a coroutine')

      local result = nil
      vim.ui.select(options, {
        prompt = 'Select a project:',
        format_item = function(item)
          return item.name
        end,
      }, function(selected)
        result = selected
        coroutine.resume(co, str)
      end)

      coroutine.yield()

      return result.profile
    end

    local function split_string(input, delimiter)
      local result = {}
      local pattern = string.format('([^%s]+)', delimiter)

      for match in string.gmatch(input, pattern) do
        -- Trim whitespace from each match if needed
        local trimmed = match:match '^%s*(.-)%s*$'
        table.insert(result, trimmed)
      end

      return result
    end

    local function get_debug_target(files) end

    dap.adapters.coreclr = {
      type = 'executable',
      command = 'c:/projects/tools/netcoredbg/netcoredbg',
      args = { '--interpreter=vscode' },
    }

    local myArgs = nil

    dap.configurations.cs = {
      {
        type = 'coreclr',
        name = 'netcoredbg',
        request = 'launch',
        program = function()
          local file = select_launchsettings()
          local profile = select_profile(file)

          if profile.commandLineArgs then
            myArgs = split_string(profile.commandLineArgs, ' ')
          end

          local project_path = get_project_path(file)
          local project_dir_name = vim.fn.fnamemodify(project_path, ':t')
          local csproj_file = project_path .. '/' .. project_dir_name .. '.csproj'
          local assembly_name = get_assembly_name(csproj_file)
          if not assembly_name then
            assembly_name = project_dir_name
          end
          print(assembly_name)
          print(csproj_file)

          local binary_file = project_path .. '/bin/Debug/net7.0/' .. assembly_name .. '.dll'
          binary_file = binary_file:gsub('\\', '//')
          print(binary_file)
          return binary_file
        end,
        args = function()
          return myArgs
        end,
      },
    }
  end,
}
