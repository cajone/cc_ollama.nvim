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
  -- If self.adapter is still just the string name, resolve it.
  if type(self.adapter) == "string" then
    log:debug("[Inline] Resolving adapter '%s' within submit function...", self.adapter)
    local adapters_module = require("codecompanion.adapters")
    self.adapter = adapters_module.resolve(self.adapter)
    if not self.adapter then
      log:error("[Inline] Failed to resolve adapter '%s'. Aborting.", self.adapter)
      -- Handle error: maybe return or raise, but for now, log and exit.
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
