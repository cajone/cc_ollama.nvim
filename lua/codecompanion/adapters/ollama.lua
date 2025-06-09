-- lua/codecompanion/adapters/ollama.lua
-- Modified to enable tooling via MCPHub integration.
-- SCHEMA TABLE TEMPORARILY REMOVED FOR DEBUGGING 'expected table, got string' ERROR.

local config = require("codecompanion.config")
local curl = require("plenary.curl")
local log = require("codecompanion.utils.log")
local openai = require("codecompanion.adapters.openai")

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
    return curl.get(url .. "/v1/models", {
      sync = true,
      headers = headers,
      insecure = config.adapters.opts.allow_insecure,
      proxy = config.adapters.opts.proxy,
    })
  end)
  if not ok then
    log:error("Could not get the Ollama models from " .. url .. "/v1/models.\nError: %s", response)
    return {}
  end

  local ok, json = pcall(vim.json.decode, response.body)
  if not ok then
    log:error("Could not parse the response from " .. url .. "/v1/models")
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
    tools = true,                     -- ENABLED: Indicate that this adapter supports tools
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
      return openai.handlers.tokens(self, data)
    end,
    form_parameters = function(self, params, messages)
      return openai.handlers.form_parameters(self, params, messages)
    end,
    form_messages = function(self, messages)
      return openai.handlers.form_messages(self, messages)
    end,
    form_tools = function(self, tools) -- UNCOMMENTED
      return openai.handlers.form_tools(self, tools)
    end,
    chat_output = function(self, data)
      return openai.handlers.chat_output(self, data)
    end,
    tools = { -- UNCOMMENTED
      format_tool_calls = function(self, tools)
        return openai.handlers.tools.format_tool_calls(self, tools)
      end,
      output_response = function(self, tool_call, output)
        return openai.handlers.tools.output_response(self, tool_call, output)
      end,
    },
    inline_output = function(self, data, context)
      return openai.handlers.inline_output(self, data, context)
    end,
    on_exit = function(self, data)
      return openai.handlers.on_exit(self, data)
    end,
  },
  -- REMOVED: The 'schema' table has been temporarily removed from here for debugging purposes.
  -- This is to isolate if the 'tbl_deep_extend' error is caused by schema definition conflicts.
  -- schema = {
  --   model = { ... },
  --   temperature = { ... },
  --   -- ... all other schema definitions ...
  -- },
}
