#!/bin/bash

# setup_part2_files.sh
# Part 2 of the Automated Setup and Test Script for cc_ollama.nvim plugin.
# This script focuses on writing and verifying the Lua configuration and test files
# within the cc_ollama.nvim fork.

echo "--- Starting setup_part2_files.sh (Part 2: Write & Verify Lua Plugin Files) ---"
echo "--- Current Directory: $(pwd) ---"

# Define paths
CC_OLLAMA_FORK_DIR="$HOME/git/cc_ollama.nvim"
AUTOMATION_REPORT="$CC_OLLAMA_FORK_DIR/automation_report.txt"

# Retrieve the temporary Neovim root path from the file created by setup_part1.sh
TEMP_NVIM_ROOT=$(cat "$CC_OLLAMA_FORK_DIR/.temp_nvim_root_path")
TEMP_NVIM_CONFIG_DIR="$TEMP_NVIM_ROOT/nvim"

# Paths to files within the cc_ollama.nvim fork
CC_OLLAMA_ADAPTER_FILE="$CC_OLLAMA_FORK_DIR/lua/codecompanion/adapters/ollama.lua"
CC_OLLAMA_TEST_SPEC="$CC_OLLAMA_FORK_DIR/tests/unit/adapters/ollama_adapter_spec.lua"
CC_OLLAMA_TEST_HELPERS="$CC_OLLAMA_FORK_DIR/tests/unit/helpers.lua"
CC_OLLAMA_INLINE_STRATEGY_FILE="$CC_OLLAMA_FORK_DIR/lua/codecompanion/strategies/inline/init.lua"
CC_OLLAMA_CONFIG_FILE="$CC_OLLAMA_FORK_DIR/lua/codecompanion/config.lua"


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

EXIT_CODE=0 # Initialize global exit code for part2

# --- Define Expected File Contents (Embedded as Heredocs) ---

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

# Expected content for /home/pete/git/cc_ollama.nvim/lua/codecompanion/strategies/inline/init.lua
read -r -d '' EXPECTED_INLINE_INIT_FILE << 'EOF_INLINE_INIT_FILE'
local client = require("codecompanion.client")
local log = require("codecompanion.utils.log")
local CONSTANTS = require("codecompanion.constants")

---@class CodeCompanion.Strategy.Inline: CodeCompanion.Strategy
---@field adapter CodeCompanion.Adapter The adapter instance for this strategy
---@field opts table Configuration options for the inline strategy

local Inline = {}
Inline.__index = Inline

-- ... (other functions in Inline)

local _streaming = true

---Submit the prompts to the LLM to process
---@param prompt table The prompts to send to the LLM
---@return nil
function Inline:submit(prompt)
  log:info("[Inline] Request started")

  -- CRITICAL FIX: Ensure self.adapter is the resolved adapter object.
  -- If type is string, it means it hasn't been fully resolved yet by CodeCompanion's core.
  if type(self.adapter) == "string" then
    log:debug("[Inline] Resolving adapter '%s' within submit function...", self.adapter)
    local adapters_module = require("codecompanion.adapters")
    self.adapter = adapters_module.resolve(self.adapter)
    if not self.adapter then
      log:error("[Inline] Failed to resolve adapter '%s'. Aborting.", self.adapter)
      return
    end
    log:debug("[Inline] Adapter resolved: %s", vim.inspect(self.adapter))
  end

  -- Ensure self.adapter.opts is a table. If it's nil, create it.
  -- This is a defensive check to prevent 'attempt to index field 'opts' (a nil value)'.
  if not self.adapter.opts then
    log:warn("[Inline] Adapter '%s' resolved without an 'opts' table. Initializing an empty one.", self.adapter.name or "unknown")
    self.adapter.opts = {}
  end

  -- Inline editing only works with streaming off - We should remember the current status
  _streaming = self.adapter.opts.stream -- Safely retrieve, will be nil if not set, or false if not explicitly true
  self.adapter.opts.stream = false -- Now safe to assign, as self.adapter.opts is guaranteed to be a table

  -- Set keymaps and start diffing
  self:setup_buffer()

  self.current_request = client
    .new({ adapter = self.adapter:map_schema_to_params(), user_args = { event = "InlineStarted" } })
    :request({ messages = self.adapter:map_roles(prompt) }, {
      ---@param err string
      ---@param data table
      ---@param adapter CodeCompanion.Adapter The modified adapter from the http client
      callback = function(err, data, adapter)
        local function error(msg)
          log:error("[Inline] Request failed with error %s", msg)
        end

        if err then
          return error(err)
        end

        if data then
          data = self.adapter.handlers.inline_output(adapter, data, self.context)
          if data.status == CONSTANTS.STATUS_SUCCESS then
            return self:done(data.output)
          else
            return error(data.output)
          end
        end
      end,
    }, {
      bufnr = self.bufnr,
      context = self.context or {},
      strategy = "inline",
    })
end

return Inline
EOF_INLINE_INIT_FILE


# Expected content for /home/pete/git/cc_ollama.nvim/lua/codecompanion/config.lua (Complete File)
read -r -d '' EXPECTED_CODECOMPANION_CONFIG_FILE << 'EOF_CODECOMPANION_CONFIG_FILE'
-- lua/codecompanion/config.lua
-- This file defines CodeCompanion's default configuration.
-- FIXED: Circular dependency by setting 'ollama = {}' in the adapters table.

local providers = require("codecompanion.providers")
local ui_utils = require("codecompanion.utils.ui")

local fmt = string.format

local constants = {
  LLM_ROLE = "llm",
  USER_ROLE = "user",
  SYSTEM_ROLE = "system",
}

local defaults = {
  adapters = {
    -- LLMs -------------------------------------------------------------------
    -- IMPORTANT FIX: Define the Ollama adapter configuration as an empty table here.
    -- The actual 'codecompanion.adapters.ollama' module is loaded and configured
    -- by the CodeCompanion core's setup function, not directly here, to prevent circular dependencies.
    ollama = {},
    -- OPTIONS ----------------------------------------------------------------
    opts = {
      allow_insecure = false, -- Allow insecure connections?
      cache_models_for = 1800, -- Cache adapter models for this long (seconds)
      proxy = nil, -- [protocol://]host[:port] e.g. socks5://127.0.0.1:9999
      show_defaults = true, -- Show default adapters
      show_model_choices = true, -- Show model choices when changing adapter
    },
  },
  constants = constants,
  strategies = {
    -- CHAT STRATEGY ----------------------------------------------------------
    chat = {
      adapter = "copilot", -- Default adapter, overridden by your plugin config
      roles = {
        ---The header name for the LLM's messages
        ---@type string|fun(adapter: CodeCompanion.Adapter): string
        llm = function(adapter)
          return "CodeCompanion (" .. adapter.formatted_name .. ")"
        end,

        ---The header name for your messages
        ---@type string
        user = "Me",
      },
      tools = {
        groups = {
          ["full_stack_dev"] = {
            description = "Full Stack Developer - Can run code, edit code and modify files",
            system_prompt = "**DO NOT** make any assumptions about the dependencies that a user has installed. If you need to install any dependencies to fulfil the user's request, do so via the Command Runner tool. If the user doesn't specify a path, use their current working directory.",
            tools = {
              "cmd_runner",
              "editor",
              "create_file",
              "read_file",
              "insert_edit_into_file",
            },
          },
          ["files"] = {
            description = "Tools related to creating, reading and editing files",
            tools = {
              "create_file",
              "read_file",
              "insert_edit_into_file",
            },
          },
        },
        ["cmd_runner"] = {
          callback = "strategies.chat.agents.tools.cmd_runner",
          description = "Run shell commands initiated by the LLM",
          opts = {
            requires_approval = true,
          },
        },
        ["editor"] = {
          callback = "strategies.chat.agents.tools.editor",
          description = "Update a buffer with the LLM's response",
        },
        ["insert_edit_into_file"] = {
          callback = "strategies.chat.agents.tools.insert_edit_into_file",
          description = "Insert code into an existing file",
          opts = {
            requires_approval = true,
          },
        },
        ["create_file"] = {
          callback = "strategies.chat.agents.tools.create_file",
          description = "Create a file in the current working directory",
          opts = {
            requires_approval = true,
          },
        },
        ["read_file"] = {
          callback = "strategies.chat.agents.tools.read_file",
          description = "Read a file in the current working directory",
        },
        ["web_search"] = {
          callback = "strategies.chat.agents.tools.web_search",
          description = "Search the web for information",
          opts = {
            adapter = "tavily", -- tavily
            opts = {
              search_depth = "advanced",
              topic = "general",
              chunks_per_source = 3,
              max_results = 5,
            },
          },
        },
        ["next_edit_suggestion"] = {
          callback = "strategies.chat.agents.tools.next_edit_suggestion",
          description = "Suggest and jump to the next position to edit",
        },
        opts = {
          auto_submit_errors = false, -- Send any errors to the LLM automatically?
          auto_submit_success = true, -- Send any successful output to the LLM automatically?
        },
      },
      variables = {
        ["buffer"] = {
          callback = "strategies.chat.variables.buffer",
          description = "Share the current buffer with the LLM",
          opts = {
            contains_code = true,
            has_params = true,
          },
        },
        ["lsp"] = {
          callback = "strategies.chat.variables.lsp",
          description = "Share LSP information and code for the current buffer",
          opts = {
            contains_code = true,
          },
        },
        ["viewport"] = {
          callback = "strategies.chat.variables.viewport",
          description = "Share the code that you see in Neovim with the LLM",
          opts = {
            contains_code = true,
          },
        },
      },
      slash_commands = {
        ["buffer"] = {
          callback = "strategies.chat.slash_commands.buffer",
          description = "Insert open buffers",
          opts = {
            contains_code = true,
            provider = providers.pickers, -- telescope|fzf_lua|mini_pick|snacks|default
          },
        },
        ["fetch"] = {
          callback = "strategies.chat.slash_commands.fetch",
          description = "Insert URL contents",
          opts = {
            adapter = "jina", -- jina
            cache_path = vim.fn.stdpath("data") .. "/codecompanion/urls",
            provider = providers.pickers, -- telescope|fzf_lua|mini_pick|snacks|default
          },
        },
        ["file"] = {
          callback = "strategies.chat.slash_commands.file",
          description = "Insert a file",
          opts = {
            contains_code = true,
            max_lines = 1000,
            provider = providers.pickers, -- telescope|fzf_lua|mini_pick|snacks|default
          },
        },
        ["help"] = {
          callback = "strategies.chat.slash_commands.help",
          description = "Insert content from help tags",
          opts = {
            contains_code = false,
            max_lines = 128, -- Maximum amount of lines to of the help file to send (NOTE: Each vimdoc line is typically 10 tokens)
            provider = providers.help, -- telescope|fzf_lua|mini_pick|snacks
          },
        },
        ["image"] = {
          callback = "strategies.chat.slash_commands.image",
          description = "Insert an image",
          opts = {
            dirs = {}, -- Directories to search for images
            filetypes = { "png", "jpg", "jpeg", "gif", "webp" }, -- Filetypes to search for
            provider = providers.images, -- telescope|snacks|default
          },
        },
        ["now"] = {
          callback = "strategies.chat.slash_commands.now",
          description = "Insert the current date and time",
          opts = {
            contains_code = false,
          },
        },
        ["symbols"] = {
          callback = "strategies.chat.slash_commands.symbols",
          description = "Insert symbols for a selected file",
          opts = {
            contains_code = true,
            provider = providers.pickers, -- telescope|fzf_lua|mini_pick|snacks|default
          },
        },
        ["terminal"] = {
          callback = "strategies.chat.slash_commands.terminal",
          description = "Insert terminal output",
          opts = {
            contains_code = false,
          },
        },
        ["workspace"] = {
          callback = "strategies.chat.slash_commands.workspace",
          description = "Load a workspace file",
          opts = {
            contains_code = true,
          },
        },
      },
      keymaps = {
        options = {
          modes = {
            n = "?",
          },
          callback = "keymaps.options",
          description = "Options",
          hide = true,
        },
        completion = {
          modes = {
            i = "<C-_>",
          },
          index = 1,
          callback = "keymaps.completion",
          description = "Completion Menu",
        },
        send = {
          modes = {
            n = { "<CR>", "<C-s>" },
            i = "<C-s>",
          },
          index = 2,
          callback = "keymaps.send",
          description = "Send",
        },
        regenerate = {
          modes = {
            n = "gr",
          },
          index = 3,
          callback = "keymaps.regenerate",
          description = "Regenerate the last response",
        },
        close = {
          modes = {
            n = "<C-c>",
            i = "<C-c>",
          },
          index = 4,
          callback = "keymaps.close",
          description = "Close Chat",
        },
        stop = {
          modes = {
            n = "q",
          },
          index = 5,
          callback = "keymaps.stop",
          description = "Stop Request",
        },
        clear = {
          modes = {
            n = "gx",
          },
          index = 6,
          callback = "keymaps.clear",
          description = "Clear Chat",
        },
        codeblock = {
          modes = {
            n = "gc",
          },
          index = 7,
          callback = "keymaps.codeblock",
          description = "Insert Codeblock",
        },
        yank_code = {
          modes = {
            n = "gy",
          },
          index = 8,
          callback = "keymaps.yank_code",
          description = "Yank Code",
        },
        pin = {
          modes = {
            n = "gp",
          },
          index = 9,
          callback = "keymaps.pin_reference",
          description = "Pin Reference",
        },
        watch = {
          modes = {
            n = "gw",
          },
          index = 10,
          callback = "keymaps.toggle_watch",
          description = "Watch Buffer",
        },
        next_chat = {
          modes = {
            n = "}",
          },
          index = 11,
          callback = "keymaps.next_chat",
          description = "Next Chat",
        },
        previous_chat = {
          modes = {
            n = "{",
          },
          index = 12,
          callback = "keymaps.previous_chat",
          description = "Previous Chat",
        },
        next_header = {
          modes = {
            n = "]]",
          },
          index = 13,
          callback = "keymaps.next_header",
          description = "Next Header",
        },
        previous_header = {
          modes = {
            n = "[[",
          },
          index = 14,
          callback = "keymaps.previous_header",
          description = "Previous Header",
        },
        change_adapter = {
          modes = {
            n = "ga",
          },
          index = 15,
          callback = "keymaps.change_adapter",
          description = "Change adapter",
        },
        fold_code = {
          modes = {
            n = "gf",
          },
          index = 15,
          callback = "keymaps.fold_code",
          description = "Fold code",
        },
        debug = {
          modes = {
            n = "gd",
          },
          index = 16,
          callback = "keymaps.debug",
          description = "View debug info",
        },
        system_prompt = {
          modes = {
            n = "gs",
          },
          index = 17,
          callback = "keymaps.toggle_system_prompt",
          description = "Toggle the system prompt",
        },
        auto_tool_mode = {
          modes = {
            n = "gta",
          },
          index = 18,
          callback = "keymaps.auto_tool_mode",
          description = "Toggle automatic tool mode",
        },
        goto_file_under_cursor = {
          modes = { n = "gR" },
          index = 19,
          callback = "keymaps.goto_file_under_cursor",
          description = "Open the file under cursor in a new tab.",
        },
      },
      opts = {
        blank_prompt = "", -- The prompt to use when the user doesn't provide a prompt
        completion_provider = providers.completion, -- blink|cmp|coc|default
        register = "+", -- The register to use for yanking code
        yank_jump_delay_ms = 400, -- Delay in milliseconds before jumping back from the yanked code
        ---@type string|fun(path: string)
        goto_file_action = ui_utils.tabnew_reuse,
      },
    },
    -- INLINE STRATEGY --------------------------------------------------------
    inline = {
      adapter = "copilot",
      keymaps = {
        accept_change = {
          modes = {
            n = "ga",
          },
          index = 1,
          callback = "keymaps.accept_change",
          description = "Accept change",
        },
        reject_change = {
          modes = {
            n = "gr",
          },
          index = 2,
          callback = "keymaps.reject_change",
          description = "Reject change",
        },
      },
      variables = {
        ["buffer"] = {
          callback = "strategies.inline.variables.buffer",
          description = "Share the current buffer with the LLM",
          opts = {
            contains_code = true,
          },
        },
        ["chat"] = {
          callback = "strategies.inline.variables.chat",
          description = "Share the currently open chat buffer with the LLM",
          opts = {
            contains_code = true,
          },
        },
        ["clipboard"] = {
          callback = "strategies.inline.variables.clipboard",
          description = "Share the contents of the clipboard with the LLM",
          opts = {
            contains_code = true,
          },
        },
      },
    },
    -- CMD STRATEGY -----------------------------------------------------------
    cmd = {
      adapter = "copilot",
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
  -- PROMPT LIBRARIES ---------------------------------------------------------
  prompt_library = {
    ["Custom Prompt"] = {
      strategy = "inline",
      description = "Prompt the LLM from Neovim",
      opts = {
        index = 3,
        is_default = true,
        is_slash_cmd = false,
        user_prompt = true,
      },
      prompts = {
        {
          role = constants.SYSTEM_ROLE,
          content = function(context)
            return fmt(
              [[I want you to act as a senior %s developer. I will ask you specific questions and I want you to return raw code only (no codeblocks and no explanations). If you can't respond with code, respond with nothing]],
              context.filetype
            )
          end,
          opts = {
            visible = false,
            tag = "system_tag",
          },
        },
      },
    },
    ["Code workflow"] = {
      strategy = "workflow",
      description = "Use a workflow to guide an LLM in writing code",
      opts = {
        index = 4,
        is_default = true,
        short_name = "cw",
      },
      prompts = {
        {
          -- We can group prompts together to make a workflow
          -- This is the first prompt in the workflow
          {
            role = constants.SYSTEM_ROLE,
            content = function(context)
              return fmt(
                "You carefully provide accurate, factual, thoughtful, nuanced answers, and are brilliant at reasoning. If you think there might not be a correct answer, you say so. Always spend a few sentences explaining background context, assumptions, and step-by-step thinking BEFORE you try to answer a question. Don't be verbose in your answers, but do provide details and examples where it might help the explanation. You are an expert software engineer for the %s language",
                context.filetype
              )
            end,
            opts = {
              visible = false,
            },
          },
          {
            role = constants.USER_ROLE,
            content = "I want you to ",
            opts = {
              auto_submit = false,
            },
          },
        },
        -- This is the second group of prompts
        {
          {
            role = constants.USER_ROLE,
            content = "Great. Now let's consider your code. I'd like you to check it carefully for correctness, style, and efficiency, and give constructive criticism for how to improve it.",
            opts = {
              auto_submit = true,
            },
          },
        },
        -- This is the final group of prompts
        {
          {
            role = constants.USER_ROLE,
            content = "Thanks. Now let's revise the code based on the feedback, without additional explanations.",
            opts = {
              auto_submit = true,
            },
          },
        },
      },
    },
    ["Edit<->Test workflow"] = {
      strategy = "workflow",
      description = "Use a workflow to repeatedly edit then test code",
      opts = {
        index = 5,
        is_default = true,
        short_name = "et",
      },
      prompts = {
        {
          {
            name = "Setup Test",
            role = constants.USER_ROLE,
            opts = { auto_submit = false },
            content = function()
              -- Enable turbo mode!!!
              vim.g.codecompanion_auto_tool_mode = true

              return [[### Instructions

Your instructions here

### Steps to Follow

You are required to write code following the instructions provided above and test the correctness by running the designated test suite. Follow these steps exactly:

1. Update the code in #buffer{watch} using the @editor tool
2. Then use the @cmd_runner tool to run the test suite with `<test_cmd>` (do this after you have updated the code)
3. Make sure you trigger both tools in the same response

We'll repeat this cycle until the tests pass. Ensure no deviations from these steps.]]
            end,
          },
        },
        {
          {
            name = "Repeat On Failure",
            role = constants.USER_ROLE,
            opts = { auto_submit = true },
            -- Scope this prompt to the cmd_runner tool
            condition = function()
              return _G.codecompanion_current_tool == "cmd_runner"
            end,
            -- Repeat until the tests pass, as indicated by the testing flag
            -- which the cmd_runner tool sets on the chat buffer
            repeat_until = function(chat)
              return chat.tools.flags.testing == true
            end,
            content = "The tests have failed. Can you edit the buffer and run the test suite again?",
          },
        },
      },
    },
    ["Explain"] = {
      strategy = "chat",
      description = "Explain how code in a buffer works",
      opts = {
        index = 6,
        is_default = true,
        is_slash_cmd = false,
        modes = { "v" },
        short_name = "explain",
        auto_submit = true,
        user_prompt = false,
        stop_context_insertion = true,
      },
      prompts = {
        {
          role = constants.SYSTEM_ROLE,
          content = [[When asked to explain code, follow these steps:

1. Identify the programming language.
2. Describe the purpose of the code and reference core concepts from the programming language.
3. Explain each function or significant block of code within the provided selection.
4. Provide examples if necessary.
5. Conclude with a summary of the code's overall functionality.]],
        },
      },
    },
  }, -- This closes prompt_library table
} -- This closes defaults table

return defaults -- This returns the defaults table
EOF_CODECOMPANION_CONFIG_FILE

# Write files for the cc_ollama.nvim fork itself
write_and_verify_file "$CC_OLLAMA_ADAPTER_FILE" "EXPECTED_OLLAMA_ADAPTER_FILE" "Ollama Adapter File in Fork"
write_and_verify_file "$CC_OLLAMA_TEST_SPEC" "EXPECTED_OLLAMA_TEST_SPEC" "Ollama Test Spec in Fork"
write_and_verify_file "$CC_OLLAMA_TEST_HELPERS" "EXPECTED_TEST_HELPERS_FILE" "Test Helpers File in Fork"
write_and_verify_file "$CC_OLLAMA_INLINE_STRATEGY_FILE" "EXPECTED_INLINE_INIT_FILE" "Inline Strategy init.lua in Fork"
write_and_verify_file "$CC_OLLAMA_CONFIG_FILE" "EXPECTED_CODECOMPANION_CONFIG_FILE" "CodeCompanion Default Config File in Fork"

echo "--- Automated File Content Verification Complete ---" | tee -a "$AUTOMATION_REPORT"
echo "" | tee -a "$AUTOMATION_REPORT"

exit $EXIT_CODE
