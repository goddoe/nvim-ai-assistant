vim.cmd([[command! -range=% -nargs=1 AskToLLMVisual lua require('nvim-ai-assistant').call_llm_visual(<line1>, <line2>, <f-args>)]])
vim.cmd([[command! -nargs=1 AskToLLM lua require('nvim-ai-assistant').call_llm(<f-args>)]])
