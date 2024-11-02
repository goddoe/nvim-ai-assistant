local json = require "dkjson"

local function jobstart(cmd, handlers)
    local stdout = vim.loop.new_pipe(false)
    local stderr = vim.loop.new_pipe(false)

    local handle, pid
    local function on_exit(_, _)
        stdout:close()
        stderr:close()
        handle:close()
    end

    handle, pid = vim.loop.spawn(cmd[1], {
        args = vim.list_slice(cmd, 2),
        stdio = {nil, stdout, stderr},
    }, on_exit)

    vim.loop.read_start(stdout, handlers.on_stdout)
    vim.loop.read_start(stderr, handlers.on_stderr)

    return pid
end

-- Todo: Support other llms
local openai_api_key = os.getenv("OPENAI_API_KEY")

local win_id = nil

local system_instruction = {role="system",
                            content="너는 도움이 되는 AI Coding Assistant이다. 사용자의 질문에 기본적으로 한국어로 답변한다."}

local message_list = {system_instruction}

local function call_llm(message)
    local lastSentence = nil

    for sentence in message:gmatch("[^\n]+") do
      lastSentence = sentence
    end

    local curr_user_turn = {
      role = "user",
      content = message
    }
    table.insert(message_list, curr_user_turn)

    local params = {
      messages = message_list,
      model = "gpt-4o"
    }
    params = json.encode(params)

    local cmd = {
        "curl",
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "-H", "Authorization: Bearer " .. openai_api_key,
        "-d", params,
        "https://api.openai.com/v1/chat/completions"
    }

    local function open_floating_window(response)
       local buf = vim.api.nvim_create_buf(false, true)

       -- 응답을 개행 문자를 기준으로 분할합니다.
       local lines = {}
       for s in response:gmatch("[^\r\n]+") do
           table.insert(lines, s)
       end

       vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

       -- 창의 너비와 높이를 설정합니다.
       local width = 80
       local height = vim.api.nvim_get_option("lines")

       -- 새 창을 오른쪽에 열고 생성한 버퍼를 설정합니다.
       local win = vim.api.nvim_open_win(buf, true, {
           relative='editor',
           width=width,
           height=height,
           col=vim.api.nvim_get_option("columns") - width,
           row=0
       })
    end

    local function open_window(response)
        local buf
        local lines = {}

        -- 윈도우가 존재하는지 확인합니다.
        if win_id ~= nil and vim.api.nvim_win_is_valid(win_id) then
            -- 윈도우가 존재하는 경우, 해당 윈도우의 버퍼를 가져옵니다.
            buf = vim.api.nvim_win_get_buf(win_id)
        else
            -- 윈도우가 존재하지 않는 경우, 새로운 버퍼를 만들고 윈도우를 만듭니다.
            buf = vim.api.nvim_create_buf(false, true)
            vim.cmd('vnew')
            win_id = vim.api.nvim_get_current_win()
            vim.api.nvim_win_set_buf(win_id, buf)

            -- 창의 너비를 설정합니다.
            local width = 80
            vim.api.nvim_win_set_width(win_id, width)
        end

        -- 응답을 개행 문자를 기준으로 분할합니다.
        for s in response:gmatch("[^\r\n]+") do
            table.insert(lines, s)
        end
        table.insert(lines, '')
        table.insert(lines, '')

        -- 버퍼의 현재 길이를 가져옵니다.
        local line_count = vim.api.nvim_buf_line_count(buf)

        -- 새로운 데이터를 버퍼의 끝에 추가합니다.
        vim.api.nvim_buf_set_lines(buf, line_count, line_count, false, lines)

        -- 커서를 새로 추가된 끝 부분으로 이동합니다.
        -- vim.api.nvim_win_set_cursor(win_id, {line_count+1, 0})
        vim.api.nvim_win_set_cursor(win_id, {line_count + #lines, 0})
    end


    local function on_stdout(err, data)
        if err then
            print("ERROR: " .. err)
        elseif data then
            print(data)

            local response_all = json.decode(data)
            -- local response = response_all.choices[1].text
            local response = response_all.choices[1].message.content
      --
            local curr_bot_turn = {role="assistant",
                                   content=response }
            table.insert(message_list, curr_bot_turn)

            response = "****************************************\n" .. message .. "\n----------------------------------------\n" .. response
            

            vim.schedule(function() open_window(response) end)

        end
    end

    local function on_stderr(err, data)
        if err then
            print("ERROR: " .. err)
        elseif data then
            -- print("STDERR: " .. data)
            print("Asking..." .. lastSentence)
        end
    end

    jobstart(cmd, {on_stdout = on_stdout, on_stderr = on_stderr})
end

local function call_llm_visual(start_line, end_line, query)
    -- Get the lines in the selected range
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

    -- Now we join the lines into a single string and call the chat function
    local text = table.concat(lines, "\n")
    
    -- Append the query to the selected text
    text = text .. "\n---\n" .. query

    -- Call the chat function with the selected text and the query
    call_llm(text)
end

local function reset_message_list()
  message_list = {system_instruction}
end


local function get_curr_message_list()
  local lines = {}
  for i, message in ipairs(message_list) do
    local msg = "----------------------------------------\n" .. message.role .. "\n" .. message.content
    table.insert(lines, msg)
  end

  local msgs = table.concat(lines, "\n")
  vim.api.nvim_echo({{msgs, "Normal"}}, true, {}) -- 출력
end

local function get_curr_message_num()
  vim.api.nvim_echo({{"# of messages: " .. #message_list, "Normal"}}, true, {}) -- 출력
end


local function setup_keymap()
  require("nvim-ai-assistant.keymap")
end

local function setup_command()
  require("nvim-ai-assistant.commands")
end

local function setup()
  setup_command()
  setup_keymap()
  print("nvim-ai-assistant loaded")
end


local M = {
  call_llm_visual = call_llm_visual,
  call_llm = call_llm,
  reset_message_list = reset_message_list,
  get_curr_message_list = get_curr_message_list,
  get_curr_message_num = get_curr_message_num,
  setup_keymap = setup_keymap,
  setup_command = setup_command,
  setup = setup,
}

return M
