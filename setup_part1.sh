#!/bin/bash

# setup_part1.sh
# Part 1 of the Automated Setup and Test Script for cc_ollama.nvim plugin.
# This script handles directory creation and the setup of the minimal isolated
# Neovim init.lua for testing.

echo "--- Starting setup_part1.sh (Part 1: Directory Setup & Minimal Init.lua) ---"
echo "--- Current Directory: $(pwd) ---"

# Define paths
CC_OLLAMA_FORK_DIR="$HOME/git/cc_ollama.nvim"
AUTOMATION_REPORT="$CC_OLLAMA_FORK_DIR/automation_report.txt"

# NEW: Define a temporary root directory for the isolated Neovim environment
TEMP_NVIM_ROOT="/tmp/isolated_nvim_test_$(date +%s)"
TEMP_NVIM_CONFIG_DIR="$TEMP_NVIM_ROOT/nvim"
TEMP_NVIM_DATA_DIR="$TEMP_NVIM_ROOT/nvim_data" # Use a separate data directory for isolation

# Paths to files within the temporary Neovim environment
TEMP_INIT_LUA="$TEMP_NVIM_CONFIG_DIR/init.lua"

# Paths to files within the cc_ollama.nvim fork (these are not in the temp nvim config)
CC_OLLAMA_ADAPTER_FILE="$CC_OLLAMA_FORK_DIR/lua/codecompanion/adapters/ollama.lua"
CC_OLLAMA_TEST_SPEC="$CC_OLLAMA_FORK_DIR/tests/unit/adapters/ollama_adapter_spec.lua"
CC_OLLAMA_TEST_HELPERS="$CC_OLLAMA_FORK_DIR/tests/unit/helpers.lua"
CC_OLLAMA_INLINE_STRATEGY_FILE="$CC_OLLAMA_FORK_DIR/lua/codecompanion/strategies/inline/init.lua"
CC_OLLAMA_CONFIG_FILE="$CC_OLLAMA_FORK_DIR/lua/codecompanion/config.lua"


# Clear previous report (only from part1)
> "$AUTOMATION_REPORT"

# --- 1. Ensure required directories exist ---
echo "1. Ensuring necessary directories exist..." | tee -a "$AUTOMATION_REPORT"

# Create temporary directories for the isolated Neovim config
mkdir -p "$TEMP_NVIM_CONFIG_DIR"
mkdir -p "$TEMP_NVIM_DATA_DIR" # Ensure data dir exists for Lazy.nvim
mkdir -p "$(dirname "$CC_OLLAMA_ADAPTER_FILE")" # For the adapter file in the fork itself
mkdir -p "$(dirname "$CC_OLLAMA_TEST_SPEC")"    # For test spec in the fork
mkdir -p "$(dirname "$CC_OLLAMA_TEST_HELPERS")" # For test helpers in the fork
mkdir -p "$(dirname "$CC_OLLAMA_INLINE_STRATEGY_FILE")" # For the inline strategy file in the fork
mkdir -p "$(dirname "$CC_OLLAMA_CONFIG_FILE")" # For the main config.lua file in the fork

echo "   Directories checked/created." | tee -a "$AUTOMATION_REPORT"


# --- Define Expected File Contents (Embedded as Heredocs) ---

# Expected content for the minimal init.lua within the temporary Neovim config
read -r -d '' EXPECTED_TEMP_INIT_LUA << 'EOF_TEMP_INIT_LUA'
-- init.lua (within temporary Neovim config)
-- This is the primary entry point for the isolated Neovim test environment.
-- All plugin definitions are consolidated here to avoid 'import' issues.

-- Set Neovim leader key
vim.g.mapleader = '\\'
vim.g.maplocalleader = '\\'

-- Basic Neovim settings for a headless environment
vim.opt.compatible = false
vim.opt.termguicolors = false -- No need for true colors in headless
vim.opt.syntax = "off"        -- No need for syntax highlighting in headless

-- Lazy.nvim Bootstrap
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Configure lazy.nvim to load ALL necessary plugins directly
require("lazy").setup({
  checker = { enable = true, notify = false },
  defaults = { lazy = false, version = false },
  change_detection = { notify = false },

  -- Essential dependencies for CodeCompanion and its tests
  "nvim-lua/plenary.nvim",
  "nvim-treesitter/nvim-treesitter",

  -- Your forked CodeCompanion plugin
  {
    "cajone/cc_ollama.nvim",
    branch = "cleanup", -- This tells Lazy.nvim to use your 'cleanup' branch
    opts = {
      log_level = "debug", -- Set to "debug" for verbose output during troubleshooting
      strategies = {
        chat = {
          adapter = "ollama", -- Use the "ollama" adapter as defined in the plugin's internal config.
          provider = "ollama", -- Keep provider for consistency if needed by CodeCompanion.
          system_prompt = function()
            -- Minimal prompt for testing adapter functionality
            local hub = require("mcphub").get_hub_instance()
            if hub then
              return hub:get_active_servers_prompt()
            else
              return "You are an AI programming assistant."
            end
          end,
        },
        inline = {
          adapter = "ollama", -- Use the "ollama" adapter as defined in the plugin's internal config.
          provider = "ollama", -- Keep provider for consistency if needed by CodeCompanion.
          keymaps = {},
          variables = {},
          opts = {
            blank_prompt = "",
            completion_provider = nil,
            register = "+",
            yank_jump_delay_ms = 400,
            goto_file_action = nil,
          },
        },
        cmd = {
          adapter = "ollama",
          provider = "ollama",
          opts = {
            system_prompt = "",
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
      mappings = {}, -- No keymaps needed for headless test
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      {
        "ravitemer/mcphub.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
        build = "npm install",
        config = function()
          require("mcphub").setup({
            port = 4000,
            host = "localhost",
            -- Point to the *user's* config file for mcp-hub server definitions,
            -- as the mcp-hub process itself uses this.
            config = vim.fn.expand("~/.config/mcphub/servers.json"),
            use_bundled_binary = false,
            log = { level = vim.log.levels.DEBUG, to_file = true, file_path = "/tmp/mcphub_debug_isolated.log" },
          })
        end,
      },
    },
    config = function(_, opts)
      require("codecompanion").setup(opts)
    end,
  },
}, {
  -- Lazy.nvim root directory for plugins. This is where Lazy.nvim will store
  -- the installed plugins relative to the isolated data dir (TEMP_NVIM_DATA_DIR).
  -- This ensures plugin installations are isolated from your main Neovim setup.
  root = vim.fn.stdpath("data") .. "/lazy",
})
EOF_TEMP_INIT_LUA


# --- 2. Writing and Verifying minimal init.lua ---
echo "2. Writing and Verifying minimal init.lua..." | tee -a "$AUTOMATION_REPORT"

# Function to write and verify a file (local to this script)
write_and_verify_file() {
    local file_path="$1"
    local expected_content_var="$2" # Name of the variable holding expected content
    local file_description="$3"

    echo "   Writing $file_description ($file_path)..." | tee -a "$AUTOMATION_REPORT"
    # Use indirect expansion to get the content of the variable and write it
    eval "cat <<< \"\$$expected_content_var\" > \"$file_path\""
    if [ $? -ne 0 ]; then
        echo "   ERROR: Failed to write $file_description." | tee -a "$AUTOMATION_REPORT"
        EXIT_CODE=1
        return
    fi

    echo "   Verifying content of $file_description ($file_path)..." | tee -a "$AUTOMATION_REPORT"
    local current_content
    current_content=$(cat "$file_path")
    local expected_content
    eval "expected_content=\$$expected_content_var" # Get content from variable

    if diff -u <(echo "$expected_content") <(echo "$current_content") > /dev/null; then
        echo "   SUCCESS: Content of $file_description MATCHES expected." | tee -a "$AUTOMATION_REPORT"
    else
        echo "   FAILURE: Content of $file_description DOES NOT MATCH expected. Diff details below:" | tee -a "$AUTOMATION_REPORT"
        diff -u <(echo "$expected_content") <(echo "$current_content") | tee -a "$AUTOMATION_REPORT"
        EXIT_CODE=1
    fi
}

EXIT_CODE=0 # Initialize global exit code for part1

# Write files for the *isolated* Neovim environment
write_and_verify_file "$TEMP_INIT_LUA" "EXPECTED_TEMP_INIT_LUA" "Temporary Nvim init.lua"

echo "--- Minimal File Content Verification Complete ---" | tee -a "$AUTOMATION_REPORT"
echo "" | tee -a "$AUTOMATION_REPORT"

# Store the path to the temporary root directory for setup_part2.sh and setup_part3.sh
echo "$TEMP_NVIM_ROOT" > "$CC_OLLAMA_FORK_DIR/.temp_nvim_root_path"

exit $EXIT_CODE
