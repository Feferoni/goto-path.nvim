-- init.lua
-- init.lua:2
-- init.lua:2:2
-- init.lua:2:2:
-- <init.lua>
-- "init.lua"
-- $(REPO)/lua/goto-path/init.lua:44:3
-- ${REPO}/lua/goto-path/init.lua:44:3
-- asda"init.lua",123
-- asda[init.lua],123
-- asda<init.lua>,123

local function filenameFirst(_, path)
    local tail = vim.fs.basename(path)
    local parent = vim.fs.dirname(path)
    if parent == "." then return tail end
    return string.format("%s\t\t%s", tail, parent)
end

vim.api.nvim_create_autocmd("FileType", {
    pattern = "TelescopeResults",
    callback = function(ctx)
        vim.api.nvim_buf_call(ctx.buf, function()
            vim.fn.matchadd("TelescopeParent", "\t\t.*$")
            vim.api.nvim_set_hl(0, "TelescopeParent", { link = "Comment" })
        end)
    end,
})

local getLnum = function(lnum, bufnr)
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_count then
        return math.max(1, math.min(lnum, line_count))
    end

    return 0
end

local getCnum = function(lnum, cnum, bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)
    if lines and lines[1] then
        return math.max(0, math.min(string.len(lines[1]), cnum) - 1)
    else
        return 0
    end
end

local jump_to_line = function(lnum, bufnr)
    local ns_highlight = vim.api.nvim_create_namespace "telescope.highlight"
    vim.api.nvim_buf_call(bufnr, function()
        lnum = getLnum(lnum, bufnr)
        vim.api.nvim_win_set_cursor(0, { lnum, 0 })
        vim.cmd("normal! zz")
        vim.api.nvim_buf_clear_namespace(bufnr, ns_highlight, 0, -1)
        vim.api.nvim_buf_add_highlight(bufnr, ns_highlight, "TelescopePreviewLine", lnum - 1, 0, -1)
    end)
end

local get_custom_previwer = function(opts, lnum)
    local previewers = require "telescope.previewers"
    local from_entry = require "telescope.from_entry"
    local conf = require("telescope.config").values
    local Path = require "plenary.path"

    return previewers.new_buffer_previewer {
        title = "Custom preview",
        dyn_title = function(_, entry)
            return Path:new(from_entry.path(entry, false, false)):normalize("")
        end,

        get_buffer_by_name = function(_, entry)
            return from_entry.path(entry, false)
        end,

        define_preview = function(self, entry)
            local has_buftype = entry.bufnr
                and vim.api.nvim_buf_is_valid(entry.bufnr)
                and vim.api.nvim_buf_get_option(entry.bufnr, "buftype") ~= ""
                or false
            local p
            if not has_buftype then
                p = from_entry.path(entry, true)
                if p == nil or p == "" then
                    return
                end
            end

            if entry.bufnr and (p == "[No Name]" or has_buftype) then
                jump_to_line(lnum, entry.bufnr)
            else
                conf.buffer_previewer_maker(p, self.state.bufnr, {
                    bufname = self.state.bufname,
                    winid = self.state.winid,
                    preview = opts.preview,
                    callback = function(bufnr)
                        jump_to_line(lnum, bufnr)
                    end,
                    file_encoding = opts.file_encoding,
                })
            end
        end
    }
end

local get_attach_mapping = function(lnum, cnum)
    return function()
        local actions = require('telescope.actions')
        actions.select_default:enhance {
            post = function()
                vim.api.nvim_win_set_cursor(0, { getLnum(lnum, 0), getCnum(lnum, cnum, 0) })
                vim.cmd("normal! zz")
            end,
        }
        return true
    end
end

local is_whitespace = function(line, pos)
    local char_at_cursor = line:sub(pos, pos)
    if char_at_cursor:match('%s') then
        return true
    end
    return false
end

local try_open_file = function(opts, file_path, lnum, cnum)
    local file_exists = vim.fn.filereadable(file_path) == 1
    if file_exists then
        vim.api.nvim_command("edit " .. vim.fn.fnameescape(file_path))
        vim.api.nvim_win_set_cursor(0, { getLnum(lnum, 0), getCnum(lnum, cnum, 0) })
        vim.cmd("normal! zz")
        return true
    end

    local directory_exists = vim.fn.isdirectory(file_path) == 1
    if directory_exists then
        opts.search_dirs = { file_path }
        require('telescope.builtin').find_files(opts)
        return true
    end

    return false
end

local extract_text = function(input)
    local patterns = { '"(.-)"', '<(.-)>', '[(.-)]', '%((.-)%)' }
    for _, pattern in ipairs(patterns) do
        local match = string.match(input, pattern)
        if match then
            return match
        end
    end
    return input
end

local parse_numbers_and_clean_end = function(file_name)
    file_name = extract_text(file_name)

    local numbers_part, lnum, cnum
    local first_colon_index = string.find(file_name, ":")
    if first_colon_index then
        numbers_part = file_name:sub(first_colon_index + 1)
        file_name = file_name:sub(1, first_colon_index - 1)
        lnum, cnum = numbers_part:match("(%d+):?(%d*):?")
    end

    if not lnum then
        lnum = 1
        cnum = 0
    end

    lnum = tonumber(lnum)
    cnum = tonumber(cnum) or 0
    return file_name, lnum, cnum
end

local M = {}

M.setup = function(opts)
    opts = opts or {}
end

local transform_env_vars = function(file_string)
    local pattern = "%$%b{}"
    local pattern2 = "%$%(%a[%w_]*%)"

    local function replace(match)
        local varName = match:sub(3, -2)
        local envValue = os.getenv(varName)
        return envValue or ""
    end

    file_string = file_string:gsub(pattern, replace)
    file_string = file_string:gsub(pattern2, replace)
    file_string = file_string:gsub("//+", "/") -- remove duplicate //

    print(file_string)

    return file_string
end

local open_file = function(line, opts)
    opts = opts or {}

    local file_string, lnum, cnum = parse_numbers_and_clean_end(line)

    file_string = transform_env_vars(file_string)
    if try_open_file(opts, file_string, lnum, cnum) then
        return
    end

    if opts.root_file ~= nil then
        local root_and_file_string = opts.root_file .. file_string
        if try_open_file(opts, root_and_file_string, lnum, cnum) then
            return
        end
    end

    file_string = file_string:gsub("%.%.%/", "") -- remove all instances of ../
    file_string = file_string:gsub("%.%/", "")   -- remove all instances of ./
    file_string = file_string:gsub("//+", "/")   -- remove duplicate //
    file_string = string.match(file_string, "[^/]+$")

    local find_command = (function()
        if 1 == vim.fn.executable "fd" then
            return { "fd", "--type", "f", "--color", "never", "--hidden", "--no-ignore", "-L" }
        elseif 1 == vim.fn.executable "fdfind" then
            return { "fdfind", "--type", "f", "--color", "never", "--hidden", "--no-ignore", "-L" }
        elseif 1 == vim.fn.executable "find" and vim.fn.has "win32" == 0 then
            return { "find", ".", "-type", "f" }
        end
    end)()

    local finders = require "telescope.finders"
    local make_entry = require "telescope.make_entry"
    local pickers = require "telescope.pickers"
    local utils = require "telescope.utils"
    local conf = require("telescope.config").values
    if not find_command then
        utils.notify("builtin.find_files", {
            msg = "You need to install either find, fd, or rg",
            level = "ERROR",
        })
        return
    end
    find_command[#find_command + 1] = file_string

    opts.on_complete = {
        function(picker)
            if picker.manager.linked_states.size == 1 then
                local actions = require('telescope.actions')
                actions.select_default(picker.prompt_bufnr)
            end
        end
    }
    opts.path_display = filenameFirst
    opts.attach_mappings = get_attach_mapping(lnum, cnum)
    opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)
    pickers
        .new(opts, {
            prompt_title = "Find File: " .. file_string,
            finder = finders.new_oneshot_job(find_command, opts),
            previewer = get_custom_previwer(opts, lnum),
            sorter = conf.file_sorter(opts),
        })
        :find()
end

M.goto_file = function(opts)
    opts = opts or {}
    local line = vim.api.nvim_get_current_line()
    local cursor_pos = vim.fn.col('.')

    if is_whitespace(line, cursor_pos) then
        print("Move to valid string")
        return
    end

    local current_pos = cursor_pos
    while current_pos > 0 and not is_whitespace(line, current_pos) do
        current_pos = current_pos - 1
    end

    current_pos = current_pos + 1
    local start_pos, end_pos = line:find('[^%s]*', current_pos)
    local starting_string = line:sub(start_pos, end_pos)
    open_file(starting_string, opts)
end

vim.api.nvim_create_user_command('OpenFile', function(args)
    if #args.fargs == 1 then
        local opts = {}
        opts.follow = true
        opts.no_ignore = true
        open_file(args.fargs[1], opts)
    else
        print("Error: OpenFile command requires exactly one argument.")
    end
end, { nargs = 1 })

return M
