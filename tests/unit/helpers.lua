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
