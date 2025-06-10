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
