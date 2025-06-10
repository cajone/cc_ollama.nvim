#!/bin/bash

# setup_and_test_cc_ollama.sh
# Automates the setup, configuration, and testing for cc_ollama.nvim plugin.

echo "--- Starting Automated Setup and Test Script ---"
echo "--- Current Directory: $(pwd) ---"

# Define paths
PVIM_CONFIG_DIR="$HOME/.config/pvim"
CC_OLLAMA_MAIN_CONFIG="$PVIM_CONFIG_DIR/lua/plugins/ai/cc_ollama.lua"
CC_OLLAMA_FORK_DIR="$HOME/git/cc_ollama.nvim"
CC_OLLAMA_ADAPTER_FILE="$CC_OLLAMA_FORK_DIR/lua/codecompanion/adapters/ollama.lua"
CC_OLLAMA_TEST_SPEC="$CC_OLLAMA_FORK_DIR/tests/unit/adapters/ollama_adapter_spec.lua"
CC_OLLAMA_TEST_HELPERS="$CC_OLLAMA_FORK_DIR/tests/unit/helpers.lua"
AUTOMATION_REPORT="$CC_OLLAMA_FORK_DIR/automation_report.txt"

# Clear previous report
> "$AUTOMATION_REPORT"

# --- 1. Ensure required directories exist ---
echo "1. Ensuring necessary directories exist..." | tee -a "$AUTOMATION_REPORT"
mkdir -p "$(dirname "$CC_OLLAMA_MAIN_CONFIG")"
mkdir -p "$(dirname "$CC_OLLAMA_ADAPTER_FILE")"
mkdir -p "$(dirname "$CC_OLLAMA_TEST_SPEC")"
mkdir -p "$(dirname "$CC_OLLAMA_TEST_HELPERS")" # For tests/unit/helpers.lua
echo "   Directories checked/created." | tee -a "$AUTOMATION_REPORT"

# --- Expected File Contents (Embedded as Heredocs) ---
read -r -d '' EXPECTED_CC_OLLAMA_MAIN_CONFIG << 'EOF_CC_OLLAMA_MAIN_CONFIG'
-- ~/.config/pvim/lua/plugins/ai/cc_ollama.lua
-- This file defines the setup for your forked CodeCompanion (cc_ollama.nvim)
-- and its integration with Ollama and mcphub.nvim.
-- It is designed to be imported by your main Lazy.nvim configuration.

-- IMPORTANT: NO 'require("codecompanion.*")' calls at this top level.
-- These modules become available only after CodeCompanion's 'setup' function runs.

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
    "nvim-lua/plenary.nvim",          -- Essential for async operations and HTTP requests
    "nvim-treesitter/nvim-treesitter", -- Used for syntax highlighting and parsing
    "MeanderingProgrammer/render-markdown.nvim", -- Dependency for markdown rendering
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
    -- THIS IS THE CRITICAL LINE: CodeCompanion's setup must happen first.
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
    log:error("Could not parse the response from " .. url .. "/v1/models")
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
    stream = true, -- RE-ADDED: Explicitly set 'stream = true' here.
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
    stream = { -- 'stream' definition here is for schema documentation and validation.
      default = true,
      type = "boolean",
      description = "Whether to stream responses.",
    },
    -- Other Ollama specific parameters can be added here if needed.
  },
}
EOF_OLLAMA_ADAPTER_FILE

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

# --- Function to verify file content ---
verify_file_content() {
    local file_path="$1"
    local expected_content="$2"
    local file_label="$3"
    local temp_file=$(mktemp)

    echo "$expected_content" > "$temp_file"

    echo "2. Verifying content of $file_label ($file_path)..." | tee -a "$AUTOMATION_REPORT"
    if ! diff -u "$file_path" "$temp_file" > /dev/null; then
        echo "   FAILURE: Content of $file_label DOES NOT MATCH expected. Diff details below:" | tee -a "$AUTOMATION_REPORT"
        diff -u "$file_path" "$temp_file" | tee -a "$AUTOMATION_REPORT"
        echo "" | tee -a "$AUTOMATION_REPORT"
        rm "$temp_file"
        return 1
    else
        echo "   SUCCESS: Content of $file_label MATCHES expected." | tee -a "$AUTOMATION_REPORT"
        rm "$temp_file"
        return 0
    fi
}

# --- 2. Automated File Content Verification ---
# Call the verification function for each critical Lua file
verify_file_content "$CC_OLLAMA_MAIN_CONFIG" "$EXPECTED_CC_OLLAMA_MAIN_CONFIG" "Main CodeCompanion Config"
verify_file_content "$CC_OLLAMA_ADAPTER_FILE" "$EXPECTED_OLLAMA_ADAPTER_FILE" "Ollama Adapter File"
verify_file_content "$CC_OLLAMA_TEST_SPEC" "$EXPECTED_OLLAMA_TEST_SPEC" "Ollama Test Spec"
verify_file_content "$CC_OLLAMA_TEST_HELPERS" "$EXPECTED_TEST_HELPERS_FILE" "Test Helpers File"

echo "" | tee -a "$AUTOMATION_REPORT"
echo "--- Automated File Content Verification Complete ---" | tee -a "$AUTOMATION_REPORT"
echo ""

# --- 3. Check for running processes (Ollama and mcp-hub) ---
echo "3. Checking for required background processes..." | tee -a "$AUTOMATION_REPORT"

check_process_port() {
    local port_num="$1"
    local process_name="$2"
    echo "   Checking if $process_name is running on port $port_num..." | tee -a "$AUTOMATION_REPORT"
    if lsof -i :"$port_num" -sTCP:LISTEN -n -P > /dev/null; then
        echo "   $process_name is RUNNING." | tee -a "$AUTOMATION_REPORT"
        return 0 # Success
    else
        echo "   $process_name is NOT RUNNING on port $port_num." | tee -a "$AUTOMATION_REPORT"
        return 1 # Failure
    fi
}

wait_for_process() {
    local port_num="$1"
    local process_name="$2"
    while ! check_process_port "$port_num" "$process_name"; do
        read -r -p "   Please start '$process_name' (e.g., '$process_name serve' or 'mcp-hub ...'). Press Enter when ready to re-check... " | tee -a "$AUTOMATION_REPORT"
    done
}

wait_for_process 11434 "ollama"
wait_for_process 4000 "mcp-hub"

echo "   All required processes are running." | tee -a "$AUTOMATION_REPORT"
echo "" | tee -a "$AUTOMATION_REPORT"


# --- 4. Git Operations in Source Repository ---
echo "4. Performing Git operations in $CC_OLLAMA_FORK_DIR..." | tee -a "$AUTOMATION_REPORT"
cd "$CC_OLLAMA_FORK_DIR" || { echo "Error: Could not change to $CC_OLLAMA_FORK_DIR. Exiting."; exit 1; }

git add -A # This stages all changes, including the script itself and any other modified/new files
if [ $? -ne 0 ]; then echo "Error: git add failed. Check file paths/permissions." | tee -a "$AUTOMATION_REPORT"; exit 1; fi

CURRENT_COMMIT_MESSAGE="Automated CodeCompanion Ollama Fix & Test Setup $(date +%Y-%m-%d_%H-%M-%S)"
git commit -m "$CURRENT_COMMIT_MESSAGE"
if [ $? -ne 0 ]; then
    echo "Warning: git commit failed (possibly no changes). Attempting to proceed." | tee -a "$AUTOMATION_REPORT"
    if ! git diff-index --quiet HEAD --; then
        echo "   Git commit failed for reasons other than no changes. Please check manually." | tee -a "$AUTOMATION_REPORT"
        exit 1
    fi
fi

git push origin cleanup
if [ $? -ne 0 ]; then echo "Error: git push failed. Check your Git setup." | tee -a "$AUTOMATION_REPORT"; exit 1; fi
echo "   Git operations complete." | tee -a "$AUTOMATION_REPORT"
echo "" | tee -a "$AUTOMATION_REPORT"


# --- 5. Clean Lazy.nvim Cache ---
echo "5. Cleaning Lazy.nvim cache (installed plugins)..." | tee -a "$AUTOMATION_REPORT"
rm -rf "$HOME/.local/share/pvim/lazy/cajone_cc_ollama.nvim"
rm -rf "$HOME/.local/share/pvim/lazy/ravitemer_mcphub.nvim"
rm -rf "$HOME/.local/share/pvim/lazy/MeanderingProgrammer_render-markdown.nvim"
echo "   Lazy.nvim cache cleaned." | tee -a "$AUTOMATION_REPORT"
echo "" | tee -a "$AUTOMATION_REPORT"

# --- 6. Run Neovim Headless Test ---
echo "6. Running Neovim headless test. This will start and exit Neovim automatically." | tee -a "$AUTOMATION_REPORT"
echo "   Output will be captured below:" | tee -a "$AUTOMATION_REPORT"
echo "--------------------------------------------------" | tee -a "$AUTOMATION_REPORT"
nvim --headless -u "$PVIM_CONFIG_DIR/init.lua" -c "PlenaryBustedFile $CC_OLLAMA_TEST_SPEC" -c "qa!" 2>&1 | tee -a "$AUTOMATION_REPORT"
NVIM_EXIT_CODE=$?
echo "--------------------------------------------------" | tee -a "$AUTOMATION_REPORT"
echo "Neovim headless test completed with exit code: $NVIM_EXIT_CODE" | tee -a "$AUTOMATION_REPORT"
echo "" | tee -a "$AUTOMATION_REPORT"

echo "--- Script Finished ---" | tee -a "$AUTOMATION_REPORT"

# --- 7. Provide ls -l output for the test file ---
echo "--- ls -l output for the test spec file ---" | tee -a "$AUTOMATION_REPORT"
ls -l "$CC_OLLAMA_TEST_SPEC" | tee -a "$AUTOMATION_REPORT"
echo "--------------------------------------------------" | tee -a "$AUTOMATION_REPORT"

echo ""
echo "Automated setup and test script has completed."
echo "Please provide the content of the automation report file: $AUTOMATION_REPORT"
echo "You can view its content using: cat $AUTOMATION_REPORT"
echo ""

