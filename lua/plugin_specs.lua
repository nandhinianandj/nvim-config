local utils = require("utils")

local plugin_dir = vim.fn.stdpath("data") .. "/lazy"
local lazypath = plugin_dir .. "/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  vim.fn.system {
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

-- check if firenvim is active
local firenvim_not_active = function()
  return not vim.g.started_by_firenvim
end

local plugin_specs = {
  {"nvzone/volt"},
  { "nvzone/timerly", cmd = "TimerlyToggle" },
  -- auto-completion engine
  {
    "hrsh7th/nvim-cmp",
    -- event = 'InsertEnter',
    event = "VeryLazy",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "onsails/lspkind-nvim",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-omni",
      "hrsh7th/cmp-emoji",
      --"quangnguyen30192/cmp-nvim-ultisnips",
    },
    config = function()
      require("config.nvim-cmp")
    end,
  },

  {
    "neovim/nvim-lspconfig",
    event = { "BufRead", "BufNewFile" },
    config = function()
      require("config.lsp")
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    enabled = function()
      if vim.g.is_mac then
        return true
      end
      return false
    end,
    event = "VeryLazy",
    build = ":TSUpdate",
    config = function()
      require("config.treesitter")
    end,
  },
  -- Leetcode solver 
  {
    "kawre/leetcode.nvim",
    build = ":TSUpdate html", -- if you have `nvim-treesitter` installed
    dependencies = {
        -- include a picker of your choice, see picker section for more details
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
    },
    opts = {
        -- configuration goes here
    },
  },
  -- Stochastic parrot plugin for text generation focused with LLMs
  {
    "frankroeder/parrot.nvim",
    dependencies = { 'ibhagwan/fzf-lua', 'nvim-lua/plenary.nvim' },
    -- optionally include "folke/noice.nvim" or "rcarriga/nvim-notify" for beautiful notifications
    config = function()
    require("parrot").setup {
      -- The provider definitions include endpoints, API keys, default parameters,
      -- and topic model arguments for chat summarization. You can use any name
      -- for your providers and configure them with custom functions.
      providers = {
        openai = {
          name = "openai",
          endpoint = "https://api.openai.com/v1/chat/completions",
          -- endpoint to query the available models online
          model_endpoint = "https://api.openai.com/v1/models",
          api_key = os.getenv("OPENAI_API_KEY"),
          -- OPTIONAL: Alternative methods to retrieve API key
          -- Using GPG for decryption:
          -- api_key = { "gpg", "--decrypt", vim.fn.expand("$HOME") .. "/my_api_key.txt.gpg" },
          -- Using macOS Keychain:
          -- api_key = { "/usr/bin/security", "find-generic-password", "-s my-api-key", "-w" },
          --- default model parameters used for chat and interactive commands
          params = {
            chat = { temperature = 1.1, top_p = 1 },
            command = { temperature = 1.1, top_p = 1 },
          },
          -- topic model parameters to summarize chats
          topic = {
            model = "gpt-4.1-nano",
            params = { max_completion_tokens = 64 },
          },
          --  a selection of models that parrot can remember across sessions
          --  NOTE: This will be handled more intelligently in a future version
          models = {
            "gpt-4.1",
            "o4-mini",
            "gpt-4.1-mini",
            "gpt-4.1-nano",
          },
        },
        --xai = {
        --  name = "xai",
        --  endpoint = "https://api.x.ai/v1/chat/completions",
        --  model_endpoint = "https://api.x.ai/v1/language-models",
        --  api_key = os.getenv "XAI_API_KEY",
        --  params = {
        --    chat = { temperature = 1.1, top_p = 1 },
        --    command = { temperature = 1.1, top_p = 1 },
        --  },
        --  topic = {
        --    model = "grok-3-mini-beta",
        --    params = { max_completion_tokens = 64 },
        --  },
        --  models = {
        --    "grok-3-beta",
        --    "grok-3-mini-beta",
        --  },
        --},
        gemini = {
          name = "gemini",
          endpoint = function(self)
            return "https://generativelanguage.googleapis.com/v1beta/models/"
              .. self._model
              .. ":streamGenerateContent?alt=sse"
          end,
          model_endpoint = function(self)
            return { "https://generativelanguage.googleapis.com/v1beta/models?key=" .. self.api_key }
          end,
          api_key = os.getenv "GEMINI_API_KEY",
          params = {
            chat = { temperature = 1.1, topP = 1, topK = 10, maxOutputTokens = 8192 },
            command = { temperature = 0.8, topP = 1, topK = 10, maxOutputTokens = 8192 },
          },
          topic = {
            model = "gemini-1.5-flash",
            params = { maxOutputTokens = 64 },
          },
          headers = function(self)
            return {
              ["Content-Type"] = "application/json",
              ["x-goog-api-key"] = self.api_key,
            }
          end,
          models = {
            "gemini-2.5-flash-preview-05-20",
            "gemini-2.5-pro-preview-05-06",
            "gemini-1.5-pro-latest",
            "gemini-1.5-flash-latest",
            "gemini-2.5-pro-exp-03-25",
            "gemini-2.0-flash-lite",
            "gemini-2.0-flash-thinking-exp",
            "gemma-3-27b-it",
          },
          preprocess_payload = function(payload)
            local contents = {}
            local system_instruction = nil
            for _, message in ipairs(payload.messages) do
              if message.role == "system" then
                system_instruction = { parts = { { text = message.content } } }
              else
                local role = message.role == "assistant" and "model" or "user"
                table.insert(
                  contents,
                  { role = role, parts = { { text = message.content:gsub("^%s*(.-)%s*$", "%1") } } }
                )
              end
            end
            local gemini_payload = {
              contents = contents,
              generationConfig = {
                temperature = payload.temperature,
                topP = payload.topP or payload.top_p,
                maxOutputTokens = payload.max_tokens or payload.maxOutputTokens,
              },
            }
            if system_instruction then
              gemini_payload.systemInstruction = system_instruction
            end
            return gemini_payload
          end,
          process_stdout = function(response)
            if not response or response == "" then
              return nil
            end
            local success, decoded = pcall(vim.json.decode, response)
            if
              success
              and decoded.candidates
              and decoded.candidates[1]
              and decoded.candidates[1].content
              and decoded.candidates[1].content.parts
              and decoded.candidates[1].content.parts[1]
            then
              return decoded.candidates[1].content.parts[1].text
            end
            return nil
          end,
        },
        anthropic = {
          name = "anthropic",
          endpoint = "https://api.anthropic.com/v1/messages",
          model_endpoint = "https://api.anthropic.com/v1/models",
          api_key = os.getenv "ANTHROPIC_API_KEY",
          params = {
            chat = { max_tokens = 4096 },
            command = { max_tokens = 4096 },
          },
          topic = {
            model = "claude-3-5-haiku-latest",
            params = { max_tokens = 32 },
          },
          headers = function(self)
            return {
              ["Content-Type"] = "application/json",
              ["x-api-key"] = self.api_key,
              ["anthropic-version"] = "2023-06-01",
            }
          end,
          models = {
            "claude-sonnet-4-20250514",
            "claude-3-7-sonnet-20250219",
            "claude-3-5-sonnet-20241022",
            "claude-3-5-haiku-20241022",
          },
          preprocess_payload = function(payload)
            for _, message in ipairs(payload.messages) do
              message.content = message.content:gsub("^%s*(.-)%s*$", "%1")
            end
            if payload.messages[1] and payload.messages[1].role == "system" then
              -- remove the first message that serves as the system prompt as anthropic
              -- expects the system prompt to be part of the API call body and not the messages
              payload.system = payload.messages[1].content
              table.remove(payload.messages, 1)
            end
            return payload
          end,
        },
        -- perplexity = {
        --   name = "perplexity",
        --   api_key = os.getenv("PERPLEXITY_API_KEY"),
        --   endpoint = "https://api.perplexity.ai/chat/completions",
        --   headers = function(self)
        --     return {
        --       ["Content-Type"] = "application/json",
        --       ["Accept"] = "application/json",
        --       ["Authorization"] = "Bearer " .. self.api_key,
        --     }
        --   end,
        --   topic = {
        --     model = "r1-1776",
        --     params = {
        --       max_tokens = 64,
        --     },
        --   },
        --   models = {
        --     "sonar",
        --     "sonar-pro",
        --     "sonar-deep-research",
        --     "sonar-reasoning",
        --     "sonar-reasoning-pro",
        --     "r1-1776",
        --   },
        -- },
  
        ollama = {
              name = "ollama",
              endpoint = "http://localhost:11434/api/chat",
              api_key = "", -- not required for local Ollama
              params = {
                chat = { temperature = 1.5, top_p = 1, num_ctx = 8192, min_p = 0.05 },
                command = { temperature = 1.5, top_p = 1, num_ctx = 8192, min_p = 0.05 },
              },
              topic_prompt = [[
              Summarize the chat above and only provide a short headline of 2 to 3
              words without any opening phrase like "Sure, here is the summary",
              "Sure! Here's a shortheadline summarizing the chat" or anything similar.
              ]],
              topic = {
                model = "llama3.2",
                params = { max_tokens = 32 },
              },
              headers = {
                ["Content-Type"] = "application/json",
              },
              models = {
                "mistral-nemo",
                "codestral",
                "llama3",
                "gemma3",
                "granite3.1",
                "codellama",
                "gpt-oss",
                "minicpm-v",
                "deepseek-r1",
                "qwen3",
                "starcoder",
              },
              resolve_api_key = function()
                return true
              end,
              process_stdout = function(response)
                if response:match "message" and response:match "content" then
                  local ok, data = pcall(vim.json.decode, response)
                  if ok and data.message and data.message.content then
                    return data.message.content
                  end
                end
              end,
              get_available_models = function(self)
                local url = self.endpoint:gsub("chat", "")
                local logger = require "parrot.logger"
                local job = Job:new({
                  command = "curl",
                  args = { "-H", "Content-Type: application/json", url .. "tags" },
                }):sync()
                local parsed_response = require("parrot.utils").parse_raw_response(job)
                self:process_onexit(parsed_response)
                if parsed_response == "" then
                  logger.debug("Ollama server not running on " .. endpoint_api)
                  return {}
                end
  
                local success, parsed_data = pcall(vim.json.decode, parsed_response)
                if not success then
                  logger.error("Ollama - Error parsing JSON: " .. vim.inspect(parsed_data))
                  return {}
                end
  
                if not parsed_data.models then
                  logger.error "Ollama - No models found. Please use 'ollama pull' to download one."
                  return {}
                end
  
                local names = {}
                for _, model in ipairs(parsed_data.models) do
                  table.insert(names, model.name)
                end
  
                return names
              end,
            },
          },
          -- default system prompts used for the chat sessions and the command routines
          -- system_prompt = {
          --   chat = ...,
          --   command = ...
          -- },
          -- the prefix used for all commands
          -- cmd_prefix = "Prt",
          -- -- optional parameters for curl
          -- curl_params = {},
          -- -- The directory to store persisted state information like the
          -- -- current provider and the selected models
          -- state_dir = vim.fn.stdpath("data"):gsub("/$", "") .. "/parrot/persisted",
          -- -- The directory to store the chats (searched with PrtChatFinder)
          -- chat_dir = vim.fn.stdpath("data"):gsub("/$", "") .. "/parrot/chats",
          -- -- Chat user prompt prefix
          -- -- chat_user_prefix = "🗨:",
          -- -- llm prompt prefix
          -- -- Explicitly confirm deletion of a chat file
          -- chat_confirm_delete = true,
          -- -- Local chat buffer shortcuts
          -- chat_shortcut_respond = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g><C-g>" },
          -- chat_shortcut_delete = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>d" },
          -- chat_shortcut_stop = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>s" },
          -- chat_shortcut_new = { modes = { "n", "i", "v", "x" }, shortcut = "<C-g>c" },
          -- -- Option to move the cursor to the end of the file after finished respond
          -- chat_free_cursor = false,
          -- -- Default target for  PrtChatToggle, PrtChatNew, PrtContext and the chats opened from the ChatFinder
          -- -- values: popup / split / vsplit / tabnew
          -- toggle_target = "vsplit",
          -- -- The interactive user input appearing when can be "native" for
          -- -- vim.ui.input or "buffer" to query the input within a native nvim buffer
          -- -- (see video demonstrations below)
          -- user_input_ui = "native",
          -- -- Popup window layout
          -- -- border: "single", "double", "rounded", "solid", "shadow", "none"
          -- style_popup_border = "single",
  
          -- -- margins are number of characters or lines
          -- style_popup_margin_bottom = 8,
          -- style_popup_margin_left = 1,
          -- style_popup_margin_right = 2,
          -- style_popup_margin_top = 2,
          -- style_popup_max_width = 160,
  
          -- -- Prompt used for interactive LLM calls like PrtRewrite where {{llm}} is
          -- -- a placeholder for the llm name
          -- command_prompt_prefix_template = "🤖 {{llm}} ~ ",
  
          -- -- auto select command response (easier chaining of commands)
          -- -- if false it also frees up the buffer cursor for further editing elsewhere
          -- command_auto_select_response = true,
  
          -- -- Time in hours until the model cache is refreshed
          -- -- Set to 0 to deactive model caching
          -- model_cache_expiry_hours = 48,
  
          -- -- fzf_lua options for PrtModel and PrtChatFinder when plugin is installed
          -- fzf_lua_opts = {
          --     ["--ansi"] = true,
          --     ["--sort"] = "",
          --     ["--info"] = "inline",
          --     ["--layout"] = "reverse",
          --     ["--preview-window"] = "nohidden:right:75%",
          -- },
  
          -- -- Enables the query spinner animation 
          -- enable_spinner = true,
          -- -- Type of spinner animation to display while loading
          -- -- Available options: "dots", "line", "star", "bouncing_bar", "bouncing_ball"
          -- spinner_type = "star",
          -- -- Show hints for context added through completion with @file, @buffer or @directory
          -- show_context_hints = true,
  
          -- -- Show diff preview before applying changes from rewrite/append/prepend
          -- enable_preview_mode = true,
          -- preview_auto_apply = false, -- If true, applies changes automatically after preview timeout
          -- preview_timeout = 10000, -- Time in ms before auto-apply (if enabled)
          -- preview_border = "rounded",
          -- preview_max_width = 120,
          -- preview_max_height = 30,
        }end,
    },
  -- Python indent (follows the PEP8 style)
  { "Vimjas/vim-python-pep8-indent", ft = { "python" } },

  -- Python-related text object
  { "jeetsukumaran/vim-pythonsense", ft = { "python" } },

  { "machakann/vim-swap", event = "VeryLazy" },
  -- bookmark code files
  {
    "heilgar/bookmarks.nvim",
    dependencies = {
        "kkharji/sqlite.lua",
        "nvim-telescope/telescope.nvim",
        "nvim-lua/plenary.nvim",
    },
    config = function()
        require("bookmarks").setup({
            -- your configuration comes here
            -- or leave empty to use defaults
            default_mappings = true,
            db_path = vim.fn.stdpath('data') .. '/bookmarks.db'
        })
        require("telescope").load_extension("bookmarks")
    end,
    cmd = {
        "BookmarkAdd",
        "BookmarkRemove",
        "Bookmarks"
    },
    keys = {
        { "<leader>ba", "<cmd>BookmarkAdd<cr>", desc = "Add Bookmark" },
        { "<leader>br", "<cmd>BookmarkRemove<cr>", desc = "Remove Bookmark" },
        { "<leader>bj", desc = "Jump to Next Bookmark" },
        { "<leader>bk", desc = "Jump to Previous Bookmark" },
        { "<leader>bl", "<cmd>Bookmarks<cr>", desc = "List Bookmarks" },
        { "<leader>bs", desc = "Switch Bookmark List" },
    },
 },
  -- Gen AI locall with ollama
  -- Custom Parameters (with defaults)
  {
      "David-Kunz/gen.nvim",
      opts = {
          model = "mistral-nemo", -- The default model to use.
          quit_map = "q", -- set keymap to close the response window
          retry_map = "<c-r>", -- set keymap to re-send the current prompt
          accept_map = "<c-cr>", -- set keymap to replace the previous selection with the last result
          host = "localhost", -- The host running the Ollama service.
          port = "11434", -- The port on which the Ollama service is listening.
          display_mode = "float", -- The display mode. Can be "float" or "split" or "horizontal-split" or "vertical-split".
          show_prompt = false, -- Shows the prompt submitted to Ollama. Can be true (3 lines) or "full".
          show_model = false, -- Displays which model you are using at the beginning of your chat session.
          no_auto_close = false, -- Never closes the window automatically.
          file = false, -- Write the payload to a temporary file to keep the command short.
          hidden = false, -- Hide the generation window (if true, will implicitly set `prompt.replace = true`), requires Neovim >= 0.10
          init = function(options) pcall(io.popen, "ollama serve > /dev/null 2>&1 &") end,
          -- Function to initialize Ollama
          command = function(options)
              local body = {model = options.model, stream = true}
              return "curl --silent --no-buffer -X POST http://" .. options.host .. ":" .. options.port .. "/api/chat -d $body"
          end,
          -- The command for the Ollama service. You can use placeholders $prompt, $model and $body (shellescaped).
          -- This can also be a command string.
          -- The executed command must return a JSON object with { response, context }
          -- (context property is optional).
          -- list_models = '<omitted lua function>', -- Retrieves a list of model names
          result_filetype = "markdown", -- Configure filetype of the result buffer
          debug = false -- Prints errors and the command which is run.
      }
  },
  -- IDE for Lisp
  -- 'kovisoft/slimv'
  {
    "vlime/vlime",
    enabled = function()
      if utils.executable("sbcl") then
        return true
      end
      return false
    end,
    config = function(plugin)
      vim.opt.rtp:append(plugin.dir .. "/vim")
    end,
    ft = { "lisp" },
  },

  -- Super fast buffer jump
  -- {
  --   "smoka7/hop.nvim",
  --   event = "VeryLazy",
  --   config = function()
  --     require("config.nvim_hop")
  --   end,
  -- },

  -- Show match number and index for searching
  {
    "kevinhwang91/nvim-hlslens",
    branch = "main",
    keys = { "*", "#", "n", "N" },
    config = function()
      require("config.hlslens")
    end,
  },
  {
    "Yggdroot/LeaderF",
    cmd = "Leaderf",
    build = function()
      local leaderf_path = plugin_dir .. "/LeaderF"
      vim.opt.runtimepath:append(leaderf_path)
      vim.cmd("runtime! plugin/leaderf.vim")

      if not vim.g.is_win then
        vim.cmd("LeaderfInstallCExtension")
      end
    end,
  },
  "nvim-lua/plenary.nvim",
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      "nvim-telescope/telescope-symbols.nvim",
    },
  },
  --{
  --  "MeanderingProgrammer/markdown.nvim",
  --  main = "render-markdown",
  --  opts = {},
  --  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
  --},
  -- A list of colorscheme plugin you may want to try. Find what suits you.
  { "navarasu/onedark.nvim", lazy = true },
  { "sainnhe/edge", lazy = true },
  { "sainnhe/sonokai", lazy = true },
  { "sainnhe/gruvbox-material", lazy = true },
  { "sainnhe/everforest", lazy = true },
  { "EdenEast/nightfox.nvim", lazy = true },
  { "catppuccin/nvim", name = "catppuccin", lazy = true },
  { "olimorris/onedarkpro.nvim", lazy = true },
  { "marko-cerovac/material.nvim", lazy = true },
  {
    "rockyzhang24/arctic.nvim",
    dependencies = { "rktjmp/lush.nvim" },
    name = "arctic",
    branch = "v2",
  },
  { "rebelot/kanagawa.nvim", lazy = true },
  { "nvim-tree/nvim-web-devicons", event = "VeryLazy" },

  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    cond = firenvim_not_active,
    config = function()
      require("config.lualine")
    end,
  },

  {
    "akinsho/bufferline.nvim",
    event = { "BufEnter" },
    cond = firenvim_not_active,
    config = function()
      require("config.bufferline")
    end,
  },

  -- vim-startify
  {
    "mhinz/vim-startify",
  },
  -- fancy start screen
  -- {

  --  "nvimdev/dashboard-nvim",
  --  cond = firenvim_not_active,
  --  config = function()
  --    require("config.dashboard-nvim")
  --  end,
  --},

  -- {
  --   "lukas-reineke/indent-blankline.nvim",
  --   event = "VeryLazy",
  --   main = "ibl",
  --   config = function()
  --     require("config.indent-blankline")
  --   end,
  -- },
  {
    "luukvbaal/statuscol.nvim",
    opts = {},
    config = function()
      require("config.nvim-statuscol")
    end,
  },
  {
    "kevinhwang91/nvim-ufo",
    dependencies = "kevinhwang91/promise-async",
    event = "VeryLazy",
    opts = {},
    init = function()
      vim.o.foldcolumn = "1" -- '0' is not bad
      vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
      vim.o.foldlevelstart = 1 --- on start fold everything except first level folds
      vim.o.foldenable =  false
    end,
    config = function()
      require("config.nvim_ufo")
    end,
  },
  -- Highlight URLs inside vim
  { "itchyny/vim-highlighturl", event = "VeryLazy" },

  -- notification plugin
  {
    "rcarriga/nvim-notify",
    event = "VeryLazy",
    config = function()
      require("config.nvim-notify")
    end,
  },

  -- For Windows and Mac, we can open an URL in the browser. For Linux, it may
  -- not be possible since we maybe in a server which disables GUI.
  {
    "tyru/open-browser.vim",
    enabled = function()
      if vim.g.is_win or vim.g.is_mac then
        return true
      else
        return false
      end
    end,
    event = "VeryLazy",
  },

  -- Only install these plugins if ctags are installed on the system
  -- show file tags in vim window
  -- {
  --   "liuchengxu/vista.vim",
  --   enabled = function()
  --     if utils.executable("ctags") then
  --       return true
  --     else
  --       return false
  --     end
  --   end,
  --   cmd = "Vista",
  -- },

  -- Snippet engine and snippet template
  -- { "SirVer/ultisnips", dependencies = {
  --   "honza/vim-snippets",
  -- }, event = "InsertEnter" },

  -- Automatic insertion and deletion of a pair of characters
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
  },

  -- Comment plugin
  { "tpope/vim-commentary", event = "VeryLazy" },

  -- Multiple cursor plugin like Sublime Text?
  -- 'mg979/vim-visual-multi'

  -- Autosave files on certain events
  -- { "907th/vim-auto-save", event = "InsertEnter" },

  -- Show undo history visually
  { "simnalamburt/vim-mundo", cmd = { "MundoToggle", "MundoShow" } },

  -- better UI for some nvim actions
  { "stevearc/dressing.nvim" },

  -- Manage your yank history
  {
    "gbprod/yanky.nvim",
    cmd = { "YankyRingHistory" },
    config = function()
      require("config.yanky")
    end,
  },

  -- Handy unix command inside Vim (Rename, Move etc.)
  { "tpope/vim-eunuch", cmd = { "Rename", "Delete" } },

  -- Repeat vim motions
  { "tpope/vim-repeat", event = "VeryLazy" },

  { "nvim-zh/better-escape.vim", event = { "InsertEnter" } },

  {
    "lyokha/vim-xkbswitch",
    enabled = function()
      if vim.g.is_mac and utils.executable("xkbswitch") then
        return true
      end
      return false
    end,
    event = { "InsertEnter" },
  },

  {
    "Neur1n/neuims",
    enabled = function()
      if vim.g.is_win then
        return true
      end
      return false
    end,
    event = { "InsertEnter" },
  },

  -- Auto format tools
  { "sbdchd/neoformat", cmd = { "Neoformat" } },

  -- Git command inside vim
  {
    "tpope/vim-fugitive",
    event = "User InGitRepo",
    config = function()
      require("config.fugitive")
    end,
  },

  -- Better git log display
  { "rbong/vim-flog", cmd = { "Flog" } },
  { "akinsho/git-conflict.nvim", version = "*", config = true },
  {
    "ruifm/gitlinker.nvim",
    event = "User InGitRepo",
    config = function()
      require("config.git-linker")
    end,
  },

  -- Show git change (change, delete, add) signs in vim sign column
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("config.gitsigns")
    end,
  },

  -- Better git commit experience
  { "rhysd/committia.vim", lazy = true },

  {
    "sindrets/diffview.nvim",
  },

  {
    "kevinhwang91/nvim-bqf",
    ft = "qf",
    config = function()
      require("config.bqf")
    end,
  },

  -- Another markdown plugin
  { "preservim/vim-markdown", ft = { "markdown" } },

  -- Faster footnote generation
  { "vim-pandoc/vim-markdownfootnotes", ft = { "markdown" } },

  -- Vim tabular plugin for manipulate tabular, required by markdown plugins
  { "godlygeek/tabular", cmd = { "Tabularize" } },

  -- Markdown previewing (only for Mac and Windows)
  {
    "iamcco/markdown-preview.nvim",
    enabled = function()
      if vim.g.is_win or vim.g.is_mac then
        return true
      end
      return false
    end,
    build = "cd app && npm install",
    ft = { "markdown" },
  },

  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    config = function()
      require("config.zen-mode")
    end,
  },

  {
    "rhysd/vim-grammarous",
    enabled = function()
      if vim.g.is_mac then
        return true
      end
      return false
    end,
    ft = { "markdown" },
  },

  { "chrisbra/unicode.vim", event = "VeryLazy" },

  -- Additional powerful text object for vim, this plugin should be studied
  -- carefully to use its full power
  { "wellle/targets.vim", event = "VeryLazy" },

  -- Plugin to manipulate character pairs quickly
  { "machakann/vim-sandwich", event = "VeryLazy" },

  -- Add indent object for vim (useful for languages like Python)
  { "michaeljsmith/vim-indent-object", event = "VeryLazy" },

  -- Only use these plugin on Windows and Mac and when LaTeX is installed
  {
    "lervag/vimtex",
    enabled = function()
      if utils.executable("latex") then
        return true
      end
      return false
    end,
    ft = { "tex" },
  },

  -- Since tmux is only available on Linux and Mac, we only enable these plugins
  -- for Linux and Mac
  -- .tmux.conf syntax highlighting and setting check
  {
    "tmux-plugins/vim-tmux",
    enabled = function()
      if utils.executable("tmux") then
        return true
      end
      return false
    end,
    ft = { "tmux" },
  },

  -- Modern matchit implementation
  { "andymass/vim-matchup", event = "BufRead" },
  { "tpope/vim-scriptease", cmd = { "Scriptnames", "Message", "Verbose" } },

  -- Asynchronous command execution
  { "skywind3000/asyncrun.vim", lazy = true, cmd = { "AsyncRun" } },
  { "cespare/vim-toml", ft = { "toml" }, branch = "main" },

  -- Edit text area in browser using nvim
  {
    "glacambre/firenvim",
    enabled = function()
      local result = vim.g.is_win or vim.g.is_mac
      return result
    end,
    -- it seems that we can only call the firenvim function directly.
    -- Using vim.fn or vim.cmd to call this function will fail.
    build = function()
      local firenvim_path = plugin_dir .. "/firenvim"
      vim.opt.runtimepath:append(firenvim_path)
      vim.cmd("runtime! firenvim.vim")

      -- macOS will reset the PATH when firenvim starts a nvim process, causing the PATH variable to change unexpectedly.
      -- Here we are trying to get the correct PATH and use it for firenvim.
      -- See also https://github.com/glacambre/firenvim/blob/master/TROUBLESHOOTING.md#make-sure-firenvims-path-is-the-same-as-neovims
      local path_env = vim.env.PATH
      local prologue = string.format('export PATH="%s"', path_env)
      -- local prologue = "echo"
      local cmd_str = string.format(":call firenvim#install(0, '%s')", prologue)
      vim.cmd(cmd_str)
    end,
  },
  -- Debugger plugin
  {
    "sakhnik/nvim-gdb",
    enabled = function()
      if vim.g.is_win or vim.g.is_linux then
        return true
      end
      return false
    end,
    build = { "bash install.sh" },
    lazy = true,
  },

  -- Session management plugin
  { "tpope/vim-obsession", cmd = "Obsession" },

  {
    "ojroques/vim-oscyank",
    enabled = function()
      if vim.g.is_linux then
        return true
      end
      return false
    end,
    cmd = { "OSCYank", "OSCYankReg" },
  },

  -- The missing auto-completion for cmdline!
  {
    "gelguy/wilder.nvim",
    build = ":UpdateRemotePlugins",
  },

  -- showing keybindings
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("config.which-key")
    end,
  },

  -- show and trim trailing whitespaces
  { "jdhao/whitespace.nvim", event = "VeryLazy" },
  -- ollama local AI model plugin
  {
  "nomnivore/ollama.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },

  -- All the user commands added by the plugin
  cmd = { "Ollama", "OllamaModel", "OllamaServe", "OllamaServeStop" },

  keys = {
    -- Sample keybind for prompt menu. Note that the <c-u> is important for selections to work properly.
    {
      "<leader>om",
      ":<c-u>:OllamaModel<cr>",
      desc = "choose ollama model",
      mode = { "n", "v" },
    },

    -- Sample keybind for direct prompting. Note that the <c-u> is important for selections to work properly.
    {
      "<leader>oo",
      ":<c-u>lua require('ollama').prompt('Generate_Code')<cr>",
      desc = "ollama Generate Code",
      mode = { "n", "v" },
    },
  },

  ---@type Ollama.Config
  opts = {
    -- your configuration overrides
  }
  },

  -- cursor AI like plugin
  -- {
  -- "yetone/avante.nvim",
  -- event = "VeryLazy",
  -- lazy = false,
  -- version = false, -- set this if you want to always pull the latest change
  -- opts = {
  --   -- add any opts here
  -- },
  -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
  -- build = "make",
  -- -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
  -- dependencies = {
  --   "nvim-treesitter/nvim-treesitter",
  --   "stevearc/dressing.nvim",
  --   "nvim-lua/plenary.nvim",
  --   "MunifTanjim/nui.nvim",
  --   --- The below dependencies are optional,
  --   "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
  --   "zbirenbaum/copilot.lua", -- for providers='copilot'
  --   {
  --     -- support for image pasting
  --     "HakonHarnes/img-clip.nvim",
  --     event = "VeryLazy",
  --     opts = {
  --       -- recommended settings
  --       default = {
  --         embed_image_as_base64 = false,
  --         prompt_for_file_name = false,
  --         drag_and_drop = {
  --           insert_mode = true,
  --         },
  --         -- required for Windows users
  --         use_absolute_path = true,
  --       },
  --     },
  --   },
  --   {
  --     -- Make sure to set this up properly if you have lazy=true
  --     'MeanderingProgrammer/render-markdown.nvim',
  --     opts = {
  --       file_types = { "markdown", "Avante" },
  --     },
  --     ft = { "markdown", "Avante" },
  --     },
  --   },
  -- },
  -- ollama caller plugin
  {
  "nomnivore/ollama.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },

    -- All the user commands added by the plugin
    cmd = { "Ollama", "OllamaModel", "OllamaServe", "OllamaServeStop" },

    keys = {
      -- Sample keybind for prompt menu. Note that the <c-u> is important for selections to work properly.
      {
        "<leader>oo",
        ":<c-u>lua require('ollama').prompt()<cr>",
        desc = "ollama prompt",
        mode = { "n", "v" },
      },

      -- Sample keybind for direct prompting. Note that the <c-u> is important for selections to work properly.
      {
        "<leader>oG",
        ":<c-u>lua require('ollama').prompt('Generate_Code')<cr>",
        desc = "ollama Generate Code",
        mode = { "n", "v" },
      },
    },

    ---@type Ollama.Config
    opts = {
          model = "granite-code:3b",
          url = "http://127.0.0.1:11434",
          serve = {
            on_start = false,
            command = "ollama",
            args = { "serve" },
            stop_command = "pkill",
            stop_args = { "-SIGTERM", "ollama" },
          },
          -- View the actual default prompts in ./lua/ollama/prompts.lua
          prompts = {
            Sample_Prompt = {
              prompt = "This is a sample prompt that receives $input and $sel(ection), among others.",
              input_label = "> ",
              model = "mistral",
              action = "display",
            }
          }
          }
},
  -- file explorer
  {
    "nvim-tree/nvim-tree.lua",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("config.nvim-tree")
    end,
  },


  {
    "j-hui/fidget.nvim",
    event = "VeryLazy",
    tag = "legacy",
    config = function()
      require("config.fidget-nvim")
    end,
  },
  {
    "folke/lazydev.nvim",
    ft = "lua", -- only load on lua files
    opts = {},
  },
}

require("lazy").setup {
  spec = plugin_specs,
  ui = {
    border = "rounded",
    title = "Plugin Manager",
    title_pos = "center",
  },
  rocks = {
    enabled = false,
  },
}
