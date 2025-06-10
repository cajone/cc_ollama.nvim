-- /tmp/minimal_test_init.lua
-- A minimal init.lua for headless CodeCompanion/Ollama/MCPHub tests.
-- This file is designed to isolate the test environment from your personal Neovim configuration.

-- Set Neovim leader key (optional, but CodeCompanion expects it)
vim.g.mapleader = '\\'
vim.g.maplocalleader = '\\'

-- Set Neovim options for a minimal environment
vim.opt.compatible = false -- Behave like Vim, not Vi
vim.opt.termguicolors = true -- Enable true colors

-- Lazy.nvim Bootstrap
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Configure lazy.nvim with only the necessary plugins for the test
require("lazy").setup({
  -- Essential for async operations and HTTP requests
  "nvim-lua/plenary.nvim",
  -- Used by CodeCompanion for syntax highlighting and parsing
  "nvim-treesitter/nvim-treesitter",
  -- Your forked CodeCompanion plugin
  {
    "cajone/cc_ollama.nvim",
    branch = "cleanup",
    opts = {
      log_level = "debug", -- Set to "debug" for verbose output during troubleshooting
      strategies = {
        chat = {
          adapter = "ollama",
          provider = "ollama",
          system_prompt = function()
            local hub = require("mcphub").get_hub_instance()
            if hub then
              return hub:get_active_servers_prompt()
            else
              return "You are an AI programming assistant named \"CodeCompanion\". You are currently plugged into the Neovim text editor."
            end
          end,
        },
        inline = { -- Required for the ollama adapter to resolve correctly
          adapter = "ollama",
          provider = "ollama",
          keymaps = {}, -- Minimal keymaps, not used by the test spec itself
          variables = {}, -- Minimal variables
          opts = {
            blank_prompt = "",
            completion_provider = nil,
            register = "+",
            yank_jump_delay_ms = 400,
            goto_file_action = nil,
          },
        },
        cmd = { -- Required for the ollama adapter to resolve correctly
          adapter = "ollama",
          provider = "ollama",
          opts = {
            system_prompt = "", -- Minimal prompt
          },
        },
      },
      extensions = {
        mcphub = {
          callback = "mcphub.extensions.codecompanion",
          opts = {
            make_vars = true,
            make_slash_commands = true,
            show_result_in_chat = true
          },
        },
      },
      mappings = {
        open_chat = "<leader>cc",
        clear_chat = "<leader>cz",
        send_selection = "<leader>cs",
      },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      {
        "ravitemer/mcphub.nvim",
        dependencies = {
          "nvim-lua/plenary.nvim",
        },
        build = "npm install",
        config = function()
          require("mcphub").setup({
            port = 4000,
            host = "localhost",
            config = vim.fn.expand("~/.config/mcphub/servers.json"),
            use_bundled_binary = false,
            log = {
              level = vim.log.levels.DEBUG,
              to_file = true,
              file_path = vim.fn.expand("~/.config/mcphub/mcphub_debug.log"),
            },
          })
        end,
      },
    },
    config = function(_, opts)
      require("codecompanion").setup(opts)
      -- Keymaps are not strictly needed for the headless unit test, but set them if CodeCompanion expects them.
      vim.keymap.set("n", opts.mappings.open_chat, "<cmd>CodeCompanion<CR>", { desc = "CodeCompanion: Open Chat" })
      vim.keymap.set("n", opts.mappings.clear_chat, "<cmd>CodeCompanionClearChat<CR>", { desc = "CodeCompanion: Clear Chat" })
      vim.keymap.set("v", opts.mappings.send_selection, "<cmd>CodeCompanion<CR>", { desc = "CodeCompanion: Open Chat with Selection Context" })
      vim.keymap.set("v", opts.mappings.open_chat, "<cmd>CodeCompanion<CR>", { desc = "CodeCompanion: Open Chat (from Visual mode)" })
    end,
  },
})
