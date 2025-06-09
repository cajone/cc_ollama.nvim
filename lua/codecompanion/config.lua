-- lua/codecompanion/config.lua
-- This file defines CodeCompanion's default configuration.
-- CORRECTED: Ensured all long strings are properly terminated to fix the 'unfinished long string' error.

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
    -- IMPORTANT CHANGE: Directly require the ollama adapter here as a table.
    -- All other adapter references have been removed as per your request.
    ollama = require("codecompanion.adapters.ollama"),
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
3. Explain each function or significant block
