vim.cmd([[command! -range=% -nargs=1 NaaAskVisual lua require('nvim-ai-assistant').call_llm_visual(<line1>, <line2>, <f-args>)]])
vim.cmd([[command! -nargs=1 NaaAsk lua require('nvim-ai-assistant').call_llm(<f-args>)]])
vim.cmd([[command! NaaResetMsgs lua require('nvim-ai-assistant').reset_message_list()]])
vim.cmd([[command! NaaGetMsgs lua require('nvim-ai-assistant').get_curr_message_list()]])
vim.cmd([[command! NaaGetNumMsgs lua require('nvim-ai-assistant').get_curr_message_num()]])
