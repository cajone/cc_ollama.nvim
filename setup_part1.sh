#!/bin/bash

# setup_part1.sh
# Part 1 of the Automated Setup and Test Script for cc_ollama.nvim plugin.
# This version creates a completely isolated, temporary Neovim environment
# for the tests to prevent interference with the user's main Neovim config.
# It consolidates all plugin definitions directly into the temporary init.lua.

echo "--- Starting setup_part1.sh ---"
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
          adapter = "ollama",
          provider = "ollama",
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


# Expected content for /home/pete/git/cc_ollama.nvim/lua/codecompanion/adapters/ollama.lua
read -r -d '' EXPECTED_OLLAMA_ADAPTER_FILE << 'EOF_OLLAMA_ADAPTER_FILE'
-- lua/codecompanion/adapters/ollama.lua
-- Modified to enable tooling via MCPHub integration and correctly handle Ollama API responses.

local config = require("codecompanion.config")
local curl = require("plenary.curl")
local log = require("codecompanion.utils.log")
local openai = require("codecompanion.adapters.openai") -- Still used for compatible handlers

local _cached_adapter

---Get a list of available Ollama models
---@params self CodeCompanion.Adapter
---@params opts? table
---@return table
local function get_models(self, opts)
  -- Prevent the adapter from being resolved multiple times due to `get_models`
  -- having both `default` and `choices` functions
  if not _cached_adapter then
    local adapter = require("codecompanion.adapters").resolve(self)
    if not adapter then
      log:error("Could not resolve Ollama adapter in the `get_models` function")
      return {}
    end
    _cached_adapter = adapter
  end

  _cached_adapter:get_env_vars()
  local url = _cached_adapter.env_replaced.url

  local headers = {
    ["content-type"] = "application/json",
  }

  local ok, response = pcall(function()
    -- Ollama's native API for listing models is /api/tags
    return curl.get(url .. "/api/tags", {
      sync = true,
      headers = headers,
      insecure = config.adapters.opts.allow_insecure,
      proxy = config.adapters.opts.proxy,
    })
  end)
  if not ok then
    log:error("Could not get the Ollama models from " .. url .. "/api/tags.\nError: %s", response)
    return {}
  end

  local ok, json = pcall(vim.json.decode, response.body)
  if not ok then
    log:error("Could not parse the response from " .. url .. "/api/tags")
    return {}
  end

  local models = {}
  -- Ollama's native /api/tags response structure is { models = [{name: "...", ...}] }
  if json and json.models then
    for _, model in ipairs(json.models) do
      table.insert(models, model.name)
    end
  -- Fallback for OpenAI compatible response structure if Ollama ever supported it for /v1/models
  elseif json and json.data then
    for _, model in ipairs(json.data) do
      table.insert(models, model.id)
    end
  end

  if opts and opts.last then
    return models[1] -- Return the first model found
  end
  return models
end

---@class Ollama.Adapter: CodeCompanion.Adapter
return {
  name = "ollama",
  formatted_name = "Ollama",
  roles = {
    llm = "assistant",
    user = "user",
  },
  opts = {
    stream = true,
    tools = true, -- ENABLED: Set to true to allow tool usage
    vision = false,
  },
  features = {
    text = true,
    tokens = true,
    tools = true, -- ENABLED: Indicate that this adapter supports tools
  },
  -- For OpenAI-compatible chat, use /v1/chat/completions.
  -- For native Ollama API, it would be /api/chat. We'll assume OpenAI compatibility for now.
  url = "${url}/v1/chat/completions",
  env = {
    url = "http://localhost:11434",
  },
  handlers = {
    -- Some handlers can still leverage OpenAI's logic if the API is compatible.
    setup = function(self)
      return openai.handlers.setup(self)
    end,
    tokens = function(self, data)
      -- This needs to be adapted for Ollama's streaming response if stream=true is used.
      -- For non-streaming, `data.message.content` is relevant.
      -- For streaming, it might be `data.delta.content` or similar.
      -- For now, we'll return content directly if it exists, otherwise pass to OpenAI's token handler.
      if data and data.message and data.message.content then
        return data.message.content
      elseif data and data.content then -- for raw completion API without chat structure
        return data.content
      else
        return openai.handlers.tokens(self, data) -- Fallback if Ollama stream format is similar to OpenAI
      end
    end,
    form_parameters = function(self, params, messages)
      return openai.handlers.form_parameters(self, params, messages)
    end,
    form_messages = function(self, messages)
      return openai.handlers.form_messages(self, messages)
    end,
    form_tools = function(self, tools)
      return openai.handlers.form_tools(self, tools)
    end,
    -- CORRECTED: Custom chat_output handler for Ollama's response structure
    chat_output = function(self, data)
      log:trace("[Ollama Adapter] chat_output data received: %s", vim.inspect(data))
      if data and data.message and data.message.content then
        return {
          output = data.message.content,
          status = "success",
        }
      end
      log:error("[Ollama Adapter] Failed to get chat output from data: %s", vim.inspect(data))
      return { output = "Error: Invalid Ollama chat response structure.", status = "error" }
    end,
    tools = {
      format_tool_calls = function(self, tools)
        return openai.handlers.tools.format_tool_calls(self, tools)
      end,
      output_response = function(self, tool_call, output)
        return openai.handlers.tools.output_response(self, tool_call, output)
      end,
    },
    -- CORRECTED: Custom inline_output handler for Ollama's response structure
    inline_output = function(self, data, context)
      log:trace("[Ollama Adapter] inline_output data received: %s", vim.inspect(data))
      -- Inline output typically expects the content directly, not wrapped in chat message.
      -- Assuming similar structure as chat_output for consistency in data received from http.lua.
      if data and data.message and data.message.content then
        return {
          output = data.message.content,
          status = "success",
        }
      end
      log:error("[Ollama Adapter] Failed to get inline output from data: %s", vim.inspect(data))
      return { output = "Error: Invalid Ollama inline response structure.", status = "error" }
    end,
    on_exit = function(self, data)
      return openai.handlers.on_exit(self, data)
    end,
  },
  -- RE-INTRODUCED: The 'schema' table with common Ollama parameters.
  -- This defines the expected configuration options for the Ollama adapter.
  schema = {
    model = {
      default = "qwen2.5-coder:latest",
      type = "string",
      description = "The Ollama model to use for generation.",
      choices = get_models, -- Function to dynamically get available models
    },
    temperature = {
      default = 0.7,
      type = "number",
      description = "Controls randomness in the output (0.0-1.0).",
    },
    top_p = {
      default = 0.9,
      type = "number",
      description = "Controls diversity via nucleus sampling (0.0-1.0).",
    },
    num_ctx = {
      default = 4096,
      type = "integer",
      description = "Sets the context window size.",
    },
    num_predict = {
      default = -1, -- -1 means predict until the model finishes
      type = "integer",
      description = "The maximum number of tokens to predict.",
    },
    stop = {
      default = nil,
      type = "array",
      description = "One or more strings to stop generation at.",
    },
    -- 'stream' is already defined in adapter's opts.
    -- Other Ollama specific parameters can be added here if needed.
  },
}
EOF_OLLAMA_ADAPTER_FILE

# Expected content for /home/pete/git/cc_ollama.nvim/tests/unit/adapters/ollama_adapter_spec.lua
read -r -d '' EXPECTED_OLLAMA_TEST_SPEC << 'EOF_OLLAMA_ADAPTER_TEST_CODE'
-- ~/git/cc_ollama/tests/unit/adapters/ollama_adapter_spec.lua
-- Unit test for the Ollama adapter in CodeCompanion.nvim.
-- This test verifies that the Ollama adapter's 'stream' option is correctly initialized.

local helpers = require("tests.unit.helpers")
local log = require("codecompanion.utils.log")

-- Mock CodeCompanion's config to control test environment
local mock_config = {
  adapters = {
    opts = { -- Global adapter options
      allow_insecure = false,
      proxy = nil,
    },
  },
  -- Mock the global adapters table which CodeCompanion uses for resolution
  adapters = {
    ollama = require("codecompanion.adapters.ollama"), -- Load the actual ollama adapter definition
    -- Any other adapters CodeCompanion might expect can be mocked here.
  },
}

-- Use plenary.test_harness to define the test suite
describe("Ollama Adapter", function()
  -- Use a before_each hook to reset or set up mocks for each test
  before_each(function()
    -- Temporarily set CodeCompanion's config to our mock config
    -- This relies on CodeCompanion exposing a way to inject config,
    -- or if not, we'd mock 'require("codecompanion.config")' directly.
    -- This is a common pattern for mocking in Lua.
    package.loaded["codecompanion.config"] = mock_config
  end)

  -- After each test, clean up the mock
  after_each(function()
    package.loaded["codecompanion.config"] = nil -- Unload the mock config
  end)

  it("should have stream=true in its opts when resolved", function()
    -- When the Ollama adapter is loaded and resolved by CodeCompanion's internal logic,
    -- its 'opts' table should contain 'stream = true'.
    local adapters_module = require("codecompanion.adapters")
    local resolved_ollama_adapter = adapters_module.resolve("ollama")

    -- Check if the adapter was resolved successfully
    assert.truthy(resolved_ollama_adapter, "Ollama adapter should be resolved")

    -- Check if the 'opts' table exists on the resolved adapter
    assert.truthy(resolved_ollama_adapter.opts, "Resolved Ollama adapter should have an 'opts' table")

    -- Check if 'stream' is explicitly set to true in the 'opts' table
    assert.are.equal(true, resolved_ollama_adapter.opts.stream, "resolved_ollama_adapter.opts.stream should be exactly true")
  end)

  -- We can add more tests here later for other adapter properties,
  -- or to test the `inline_output` handler's functionality once this base is solid.
end)
EOF_OLLAMA_ADAPTER_TEST_CODE

# Expected content for /home/pete/git/cc_ollama.nvim/tests/unit/helpers.lua
read -r -d '' EXPECTED_TEST_HELPERS_FILE << 'EOF_TEST_HELPERS_FILE'
-- ~/git/cc_ollama/tests/unit/helpers.lua
-- Minimal helper file for Plenary tests in CodeCompanion.nvim.
-- Add common test utilities here as needed.

local helpers = {}

-- A simple utility to inspect tables for debugging within tests
function helpers.inspect(t)
  return vim.inspect(t)
end

-- Example of a basic assertion helper (though Plenary's assert is robust)
function helpers.assert_truthy(value, message)
  assert(value, message or "Value should be truthy")
end

return helpers
EOF_TEST_HELPERS_FILE


# --- 2. Write and Verify File Contents ---
echo "2. Writing and Verifying content of configuration files..." | tee -a "$AUTOMATION_REPORT"

# Function to write and verify a file
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

# Write files for the cc_ollama.nvim fork itself
write_and_verify_file "$CC_OLLAMA_ADAPTER_FILE" "EXPECTED_OLLAMA_ADAPTER_FILE" "Ollama Adapter File in Fork"
write_and_verify_file "$CC_OLLAMA_TEST_SPEC" "EXPECTED_OLLAMA_TEST_SPEC" "Ollama Test Spec in Fork"
write_and_verify_file "$CC_OLLAMA_TEST_HELPERS" "EXPECTED_TEST_HELPERS_FILE" "Test Helpers File in Fork"

echo "--- Automated File Content Verification Complete ---" | tee -a "$AUTOMATION_REPORT"
echo "" | tee -a "$AUTOMATION_REPORT"

# Store the path to the temporary root directory for setup_part2.sh
echo "$TEMP_NVIM_ROOT" > "$CC_OLLAMA_FORK_DIR/.temp_nvim_root_path"

exit $EXIT_CODE
