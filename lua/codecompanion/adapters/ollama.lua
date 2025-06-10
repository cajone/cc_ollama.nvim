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
      end -- REMOVED: extraneous '})' and 'end' were here
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
