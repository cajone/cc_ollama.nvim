#!/bin/bash

# setup_part1.sh
# Part 1 of the Automated Setup and Test Script for cc_ollama.nvim plugin.
# Handles directory creation, writing of configuration files, and verification of their contents.

echo "--- Starting setup_part1.sh ---"
echo "--- Current Directory: $(pwd) ---"

# Define paths
PVIM_CONFIG_DIR="$HOME/.config/pvim"
CC_OLLAMA_MAIN_CONFIG="$PVIM_CONFIG_DIR/lua/plugins/ai/cc_ollama.lua"
CC_OLLAMA_FORK_DIR="$HOME/git/cc_ollama.nvim"
CC_OLLAMA_ADAPTER_FILE="$CC_OLLAMA_FORK_DIR/lua/codecompanion/adapters/ollama.lua"
CC_OLLAMA_TEST_SPEC="$CC_OLLAMA_FORK_DIR/tests/unit/adapters/ollama_adapter_spec.lua"
CC_OLLAMA_TEST_HELPERS="$CC_OLLAMA_FORK_DIR/tests/unit/helpers.lua"
PVIM_LAZY_LOAD_FILE="$PVIM_CONFIG_DIR/lua/plugins/lazy_load.lua"
AUTOMATION_REPORT="$CC_OLLAMA_FORK_DIR/automation_report.txt"

# Clear previous report (only from part1)
> "$AUTOMATION_REPORT"

# --- 1. Ensure required directories exist ---
echo "1. Ensuring necessary directories exist..." | tee -a "$AUTOMATION_REPORT"
mkdir -p "$(dirname "$CC_OLLAMA_MAIN_CONFIG")"
mkdir -p "$(dirname "$CC_OLLAMA_ADAPTER_FILE")"
mkdir -p "$(dirname "$CC_OLLAMA_TEST_SPEC")"
mkdir -p "$(dirname "$CC_OLLAMA_TEST_HELPERS")"
mkdir -p "$(dirname "$PVIM_LAZY_LOAD_FILE")"
echo "   Directories checked/created." | tee -a "$AUTOMATION_REPORT"


# --- Define Expected File Contents (Embedded as Heredocs) ---

# Expected content for /home/pete/.config/pvim/lua/plugins/ai/cc_ollama.lua
read -r -d '' EXPECTED_CC_OLLAMA_MAIN_CONFIG << 'EOF_CC_OLLAMA_MAIN_CONFIG'
-- ~/.config/pvim/lua/plugins/ai/cc_ollama.lua
-- This file defines the setup for your forked CodeCompanion (cc_ollama.nvim)
-- and its integration with Ollama and mcphub.nvim.
-- It is designed to be imported by your main Lazy.nvim configuration.

-- IMPORTANT: NO 'require("codecompanion.*")' calls at this top level.
-- These modules become fully available only after CodeCompanion's 'setup' function runs.

local M = {
  -- IMPORTANT: Point Lazy.nvim to your GitHub fork and specify the 'cleanup' branch.
  -- This ensures Lazy.nvim fetches your specific version of the plugin.
  "cajone/cc_ollama.nvim",
  branch = "cleanup",

  -- Configuration options for CodeCompanion
  opts = {
    log_level = "debug", -- Set to "debug" for verbose output during troubleshooting

    -- Adapters are now expected to be defined within the forked plugin's own
    -- `lua/codecompanion/config.lua` or directly in `lua/codecompanion/adapters/ollama.lua`.
    -- Your `ollama.lua` in ~/git/cc_ollama/lua/codecompanion/adapters/ollama.lua
    -- should define the adapter with its schema, including the 'stream' option.
    -- The main plugin config here just needs to refer to it by name.
    adapters = {
      -- We explicitly define 'ollama = nil'. CodeCompanion's `setup` will then
      -- discover and register the adapter based on its definition in your forked plugin.
      ollama = nil,
    },

    -- Define strategies for CodeCompanion's chat, inline, and cmd interactions.
    strategies = {
      chat = {
        -- Set the primary LLM adapter for the chat strategy to "ollama".
        adapter = "ollama",
        -- 'provider' is also set to "ollama" for consistency.
        provider = "ollama",

        -- System prompt dynamically includes MCP tools
        system_prompt = function()
          local hub = require("mcphub").get_hub_instance()
          if hub then
            return hub:get_active_servers_prompt()
          else
            -- Fallback system prompt if mcphub is not ready
            return
            "You are an AI programming assistant named \"CodeCompanion\". You are currently plugged into the Neovim text editor."
          end
        end,
      },
      -- Explicitly define the 'inline' strategy.
      inline = {
        adapter = "ollama", -- Use Ollama for inline strategy
        provider = "ollama", -- Keep provider for consistency
        keymaps = {
          accept_change = {
            modes = { n = "ga" },
            index = 1,
            callback = "keymaps.accept_change",
            description = "Accept change",
          },
          reject_change = {
            modes = { n = "gr" },
            index = 2,
            callback = "keymaps.reject_change",
            description = "Reject change",
          },
        },
        variables = {
          ["buffer"] = {
            callback = "strategies.inline.variables.buffer",
            description = "Share the current buffer with the LLM",
            opts = { contains_code = true },
          },
          ["chat"] = {
            callback = "strategies.inline.variables.chat",
            description = "Share the currently open chat buffer with the LLM",
            opts = { contains_code = true },
          },
          ["clipboard"] = {
            callback = "strategies.inline.variables.clipboard",
            description = "Share the contents of the clipboard with the LLM",
            opts = { contains_code = true },
          },
        },
        opts = {
          blank_prompt = "", -- The prompt to use when the user doesn't provide a prompt
          -- These will be assigned after CodeCompanion's setup, by retrieving modules.
          completion_provider = nil,
          register = "+",
          yank_jump_delay_ms = 400,
          goto_file_action = nil,
        },
      },
      -- Explicitly define the 'cmd' strategy.
      cmd = {
        adapter = "ollama", -- Use Ollama for cmd strategy
        provider = "ollama", -- Keep provider for consistency
        opts = {
            system_prompt = [[You are currently plugged in to the Neovim text editor on a user's machine. Your core task is to generate an command-line inputs that the user can run within Neovim. Below are some rules to adhere to:

- Return plain text only
- Do not wrap your response in a markdown block or backticks
- Do not use any line breaks or newlines in you response
- Do not provide any explanations
- Generate an command that is valid and can be run in Neovim
- Ensure the command is relevant to the user's request]],
        },
      },
    },

    -- Configuration for CodeCompanion extensions (like MCPHub)
    extensions = {
      mcphub = {
        callback = "mcphub.extensions.codecompanion", -- Link to the MCPHub extension's callback
        opts = {
          make_vars = true,           -- Generate context variables from MCP resources
          make_slash_commands = true, -- Enable slash commands like `/mcp`
          show_result_in_chat = true  -- Display tool execution results in chat
        },
      },
    },

    -- Key mappings for CodeCompanion actions
    mappings = {
      open_chat = "<leader>cc",
      clear_chat = "<leader>cz",
      send_selection = "<leader>cs",
    },
  },

  -- Dependencies required by CodeCompanion
  dependencies = {
    "nvim-lua/plenary.nvim",           -- Essential for async operations and HTTP requests
    "nvim-treesitter/nvim-treesitter", -- Used for syntax highlighting and parsing
    {
      -- mcphub.nvim plugin definition
      "ravitemer/mcphub.nvim",
      dependencies = {
        "nvim-lua/plenary.nvim",
      },
      build = "npm install", -- This build step is for mcphub.nvim itself.
      config = function()
        require("mcphub").setup({
          port = 4000,                                -- MCP Hub server port
          host = "localhost",                         -- MCP Hub server host
          config = vim.fn.expand("~/.config/mcphub/servers.json"), -- Path to server definitions
          use_bundled_binary = false,                 -- Use global `mcp-hub`
          log = {
            level = vim.log.levels.DEBUG,             -- Enable debug logging for mcphub
            to_file = true,
            file_path = vim.fn.expand("~/.config/mcphub/mcphub_debug.log"),
          },
        })
      end,
    },
  },

  -- Main CodeCompanion setup function (executed after plugin loaded)
  config = function(_, opts)
    require("codecompanion").setup(opts)

    -- Now, CodeCompanion's internal modules are available.
    local adapters_module = require("codecompanion.adapters")
    local providers = require("codecompanion.providers")
    local ui_utils = require("codecompanion.utils.ui")

    -- Assign the required modules to the opts table properties for the inline strategy
    -- These were previously defined as nil placeholders and now get their actual values.
    opts.strategies.inline.opts.completion_provider = providers.completion
    opts.strategies.inline.opts.goto_file_action = ui_utils.tabnew_reuse

    -- Set up keymaps
    vim.keymap.set("n", opts.mappings.open_chat, "<cmd>CodeCompanion<CR>", { desc = "CodeCompanion: Open Chat" })
    vim.keymap.set("n", opts.mappings.clear_chat, "<cmd>CodeCompanionClearChat<CR>",
      { desc = "CodeCompanion: Clear Chat" })
    vim.keymap.set("v", opts.mappings.send_selection, "<cmd>CodeCompanion<CR>",
      { desc = "CodeCompanion: Open Chat with Selection Context" })
    vim.keymap.set("v", opts.mappings.open_chat, "<cmd>CodeCompanion<CR>",
      { desc = "CodeCompanion: Open Chat (from Visual mode)" })
  end,
}

return M
EOF_CC_OLLAMA_MAIN_CONFIG

# Expected content for /home/pete/git/cc_ollama.nvim/lua/codecompanion/adapters/ollama.lua
read -r -d '' EXPECTED_OLLAMA_ADAPTER_FILE << 'EOF_OLLAMA_ADAPTER_FILE'
-- lua/codecompanion/adapters/ollama.lua
-- Modified to enable tooling via MCPHub integration.
-- SCHEMA 'choices' for model now uses a static list to avoid dynamic function calls for debugging.

local config = require("codecompanion.config")
local curl = require("plenary.curl")
local log = require("codecompanion.utils.log")
local openai = require("codecompanion.adapters.openai")

local _cached_adapter

---Get a list of available Ollama models (NO LONGER USED FOR SCHEMA CHOICES)
---@params self CodeCompanion.Adapter
---@params opts? table
---@return table
local function get_models(self, opts)
  -- This function is kept for reference but is no longer called in the schema 'choices'.
  -- Its primary role was to dynamically fetch models, but we've temporarily removed it
  -- from the schema definition to isolate a potential parsing issue.
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
  -- Check for 'data' key for OpenAI compatible response
  if json and json.data then
    for _, model in ipairs(json.data) do
      table.insert(models, model.id)
    end
  -- Fallback for Ollama's native /api/tags response structure
  elseif json and json.models then
    for _, model in ipairs(json.models) do
      table.insert(models, model.name)
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
  url = "${url}/v1/chat/completions", -- Correct for OpenAI-compatible chat API
  env = {
    url = "http://localhost:11434",
  },
  handlers = {
    --- Use the OpenAI adapter for the bulk of the work
    setup = function(self)
      return openai.handlers.setup(self)
    end,
    tokens = function(self, data)
      if data and data.message and data.message.content then
        return data.message.content
      elseif data and data.content then -- for raw completion API without chat structure
        return data.content
      else
        return openai.handlers.tokens(self, data)
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
    inline_output = function(self, data, context)
      log:trace("[Ollama Adapter] inline_output data received: %s", vim.inspect(data))
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
  schema = {
    model = {
      default = "qwen2.5-coder:latest",
      type = "string",
      description = "The Ollama model to use for generation.",
      choices = { "qwen2.5-coder:latest", "llama3" }, -- STATIC LIST for debugging the '<eof>' error
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
    stream = { -- 'stream' definition here is for schema documentation and validation.
      default = true,
      type = "boolean",
      description = "Whether to stream responses.",
    },
    -- Other Ollama specific parameters can be added here if needed.
  },
}
return M

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
    -- For simplicity, let's assume `codecompanion.config` can be modified for testing.
    -- A more robust way might be to mock the `require` call itself.
    -- Given the error is in `inline/init.lua` where `self.adapter.opts.stream` is accessed,
    -- the issue is how the adapter is constructed when `adapters.resolve` is called.

    -- Let's ensure CodeCompanion's main config is using our mock for the adapter definition.
    -- We can override `require("codecompanion.config")` for the scope of this test.
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
    assert.truthy(resolved_ollama_adapter.opts.stream, "resolved_ollama_adapter.opts.stream should be true")
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

# Expected content for /home/pete/.config/pvim/lua/plugins/lazy_load.lua
read -r -d '' EXPECTED_LAZY_LOAD_FILE << 'EOF_LAZY_LOAD_FILE'
-- OK first setup the plugin manager "Lazy"load
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

require("lazy").setup({
  checker = { -- turns off notifications
    enable = true,
    notify = false,
  },
  defaults = {
    lazy = false,
    version = false,
  },

  change_detection = { notify = false }, -- Stop reporting auto changes

  -- Plugins used straight out the box
  { "instant-markdown/vim-instant-markdown" },     -- Instant Markdown
  { "vimwiki/vimwiki" },                         -- Vimwiki
  "MeanderingProgrammer/render-markdown.nvim",     -- ADDED/MOVED HERE: Ensure render-markdown is a top-level plugin
  "nvim-telescope/telescope.nvim",                 -- ADDED HERE: Ensure Telescope is loaded early as a top-level plugin

  { import = "plugins.obsidian" },             -- obsidian note taker
  { import = "plugins.treesitter" },
  --  { import = "plugins.arduino" },  -- Arduino front end
  --  { import = "plugins.lint" },      -- Linter(s)

  { import = "plugins.git" },            -- git related plugins
  -- { import = "plugins.render-markdown" }, -- REMOVED: Redundant import
  { import = "plugins.terminal" },         -- Toggle Terminal window
  --  { import = "plugins.markdown-preview" }, -- Instant Markdown for neovim

  -- UI based plugins
  { import = "plugins.ui.colorscheme" }, -- ColorScheme
  { import = "plugins.ui.dressing" },    -- Allows prompts and selections
  { import = "plugins.ui.lualine" },      -- Status Line
  { import = "plugins.ui.mini" },         -- Collections on notes, todo's
  { import = "plugins.ui.telescope" },    -- Fuzzy file finder and many other things
  { import = "plugins.ui.todo" },         -- Todo notes etc
  --  { import = "plugins.ui.noice" },        -- system messages popup window
  { import = "plugins.ui.conform" },      -- Formatting, linting
  --  { import = "plugins.ui.fzf-lua" }, -- Formatting, linting

  -- AI based plugins
  { import = "plugins.ai.gp" },        -- Configure AI prompt
  { import = "plugins.ai.mcphub" },    -- Configure AI prompt
  --    { import = "plugins.ai.avante" }, -- AI frontend
  { import = "plugins.ai.cc_ollama" }, -- AI frontend
  --  { import = "plugins.ai.ai" }, -- Configure AI prompt
  --  { import = "plugins.ai.copilot" }, -- Configure AI prompt

  -- LSP / Autocompletion language Plugins
  { import = "plugins.lsp.mason" },     -- LSP installer : NOTE THIS HAS TO BE THE FIRST LSP FILE TO LOAD!!!
  { import = "plugins.lsp.none-ls" },    -- null-ls replacement
  { import = "plugins.lsp.nvim-cmp" },   -- Auto Completion
  { import = "plugins.lsp.debug" },      -- LSP Debug
  { import = "plugins.lsp.lsp_config" }, -- LSP configuration

  -- DAP Debugging code base
  -- { "mfussenegger/nvim-dap" },
  -- { "jbyuki/one-small-step-for-vimkind" },
})
EOF_LAZY_LOAD_FILE

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

# Call the function for each file that needs to be written and verified
write_and_verify_file "$CC_OLLAMA_MAIN_CONFIG" "EXPECTED_CC_OLLAMA_MAIN_CONFIG" "Main CodeCompanion Config"
write_and_verify_file "$CC_OLLAMA_ADAPTER_FILE" "EXPECTED_OLLAMA_ADAPTER_FILE" "Ollama Adapter File"
write_and_verify_file "$CC_OLLAMA_TEST_SPEC" "EXPECTED_OLLAMA_TEST_SPEC" "Ollama Test Spec"
write_and_verify_file "$CC_OLLAMA_TEST_HELPERS" "EXPECTED_TEST_HELPERS_FILE" "Test Helpers File"
write_and_verify_file "$PVIM_LAZY_LOAD_FILE" "EXPECTED_LAZY_LOAD_FILE" "Main Lazy Load Config"

echo "--- Automated File Content Verification Complete ---" | tee -a "$AUTOMATION_REPORT"
echo "" | tee -a "$AUTOMATION_REPORT"

exit $EXIT_CODE

