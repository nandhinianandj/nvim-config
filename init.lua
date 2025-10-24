-- This is my personal Nvim configuration supporting Mac, Linux and Windows, with various plugins configured.
-- This configuration evolves as I learn more about Nvim and become more proficient in using Nvim.
-- Since it is very long (more than 1000 lines!), you should read it carefully and take only the settings that suit you.
-- I would not recommend cloning this repo and replace your own config. Good configurations are personal,
-- built over time with a lot of polish.
--
-- Author: Jiedong Hao
-- Email: jdhao@hotmail.com
-- Blog: https://jdhao.github.io/
-- GitHub: https://github.com/jdhao
-- StackOverflow: https://stackoverflow.com/users/6064933/jdhao
-- one-liner: auto-detect Python & set python3_host_prog
-- vim.g.python3_host_prog = (function() local p = vim.fn.exepath('python3') if p=='' then p = vim.fn.exepath('python') end if p=='' then local ok,f = pcall(io.popen, 'python3 -3 -c "import sys;print(sys.executable)" 2>nul') if ok and f then local s = f:read('*l') f:close() if s and s~='' then p = s end end end if p~= '' then vim.notify('python3_host_prog set → '..p) return p else vim.notify('Python3 not found — set vim.g.python3_host_prog manually', vim.log.levels.WARN) return '' end end)()

-- vim.g.python3_host_prog = "C:/Program Files/Python312/python.exe"
vim.loader.enable()

local version = vim.version
-- check if we have the latest stable version of nvim

-- local expected_ver_str = "0.10.1,0.11.0"
-- local expect_ver = version.parse(expected_ver_str)
-- local actual_ver = vim.version()
-- 
-- 
-- if expect_ver == nil then
--   local msg = string.format("Unsupported version string: %s", expected_ver_str)
--   vim.api.nvim_err_writeln(msg)
--   return
-- end
-- local actual_ver_str = string.format("%s.%s.%s", actual_ver.major, actual_ver.minor, actual_ver.patch)
-- result = string.find(expected_ver_str,actual_ver_str)
-- -- version.cmp(expect_ver, actual_ver)
-- 
-- if  result == nil then
--   local _ver = string.format("%s.%s.%s", actual_ver.major, actual_ver.minor, actual_ver.patch)
--   local msg = string.format("Expect nvim %s, but got %s instead. Use at your own risk!", expected_ver_str, _ver)
--   vim.api.nvim_err_writeln(msg)
-- end

local core_conf_files = {
  "globals.lua", -- some global settings
  "options.vim", -- setting options in nvim
  "autocommands.vim", -- various autocommands
  "mappings.lua", -- all the user-defined mappings
  -- "custom-mappings.lua",
  "plugins.vim", -- all the plugins installed and their configurations
  "colorschemes.lua", -- colorscheme settings
}

local viml_conf_dir = vim.fn.stdpath("config") .. "/viml_conf"
-- source all the core config files
for _, file_name in ipairs(core_conf_files) do
  if vim.endswith(file_name, 'vim') then
    local path = string.format("%s/%s", viml_conf_dir, file_name)
    local source_cmd = "source " .. path
    vim.cmd(source_cmd)
  else
    local module_name, _ = string.gsub(file_name, "%.lua", "")
    package.loaded[module_name] = nil
    require(module_name)
  end
end
