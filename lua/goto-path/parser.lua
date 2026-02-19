local M = {}

local ParsedPath = {}
ParsedPath.__index = ParsedPath

function ParsedPath:get_full_path()
    if self.path == "" then
        return self.file_name
    end
    return self.path .. "/" .. self.file_name
end

local extract_text = function(input)
    if input:sub(1, 1) == "$" then
        return input
    end
    local delimiters = {
        { open = '"',  close = '"' },
        { open = "'",  close = "'" },
        { open = '<',  close = '>' },
        { open = '%[', close = '%]' },
        { open = '%(', close = '%)' },
        { open = '{',  close = '}' },
    }
    for _, delim in ipairs(delimiters) do
        local pattern = '^' .. delim.open .. '(.*)' .. delim.close .. '$'
        local match = string.match(input, pattern)
        if match then
            return match
        end
        input = input:gsub('^' .. delim.open, ''):gsub(delim.close .. '$', '')
    end
    return input
end

local transform_env_vars = function(file_string)
    local patterns = { "%$%(([%w_]+)%)", "%${([%w_]+)}" }
    local function get_env(var_name)
        return os.getenv(var_name) or ""
    end
    for _, pattern in ipairs(patterns) do
        file_string = file_string:gsub(pattern, get_env)
    end
    return file_string
end

M.parse = function(input)
    input = extract_text(input)
    input = transform_env_vars(input)

    local full_path = input
    local row, column = 1, 0

    local first_colon_index = string.find(input, ":")
    if first_colon_index then
        local numbers_part = input:sub(first_colon_index + 1)
        full_path = input:sub(1, first_colon_index - 1)
        local r, c = numbers_part:match("(%d+):?(%d*):?")
        row = tonumber(r) or 1
        column = tonumber(c) or 0
    end

    local file_name = string.match(full_path, "[^/]+$") or full_path
    local path = full_path:sub(1, -(#file_name + 2))
    if path == "" or path == "/" or path == "./" then
        path = ""
    end

    return setmetatable({
        path = path,
        file_name = file_name,
        row = row,
        column = column,
    }, ParsedPath)
end

return M
