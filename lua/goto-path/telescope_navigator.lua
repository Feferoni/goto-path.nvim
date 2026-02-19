local M = {}

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
        vim.api.nvim_buf_set_extmark(bufnr, ns_highlight, lnum - 1, 0, {
            end_line = lnum,
            hl_group = "TelescopePreviewLine",
        })
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
                and vim.bo[entry.bufnr].buftype ~= ""
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

local filenameFirst = function(_, path)
    local tail = vim.fs.basename(path)
    local parent = vim.fs.dirname(path)
    if parent == "." then return tail end
    return string.format("%s\t\t%s", tail, parent)
end

local get_find_command = function()
    if vim.fn.executable("fd") == 1 then
        return { "fd", "--type", "f", "--color", "never", "--hidden", "--no-ignore", "-L" }
    elseif vim.fn.executable("fdfind") == 1 then
        return { "fdfind", "--type", "f", "--color", "never", "--hidden", "--no-ignore", "-L" }
    elseif vim.fn.executable("find") == 1 and vim.fn.has("win32") == 0 then
        return { "find", ".", "-type", "f" }
    end
    return nil
end

M.create_search = function()
    return function(parsed, opts)
        local find_command = get_find_command()
        if not find_command then
            local utils = require "telescope.utils"
            utils.notify("builtin.find_files", {
                msg = "You need to install either find, fd, or rg",
                level = "ERROR",
            })
            return false
        end

        local search_name = parsed.file_name
        find_command[#find_command + 1] = search_name

        local finders = require "telescope.finders"
        local make_entry = require "telescope.make_entry"
        local pickers = require "telescope.pickers"
        local conf = require("telescope.config").values

        opts.on_complete = {
            function(picker)
                if picker.manager.linked_states.size == 1 then
                    local actions = require('telescope.actions')
                    actions.select_default(picker.prompt_bufnr)
                end
            end
        }
        opts.path_display = filenameFirst
        opts.attach_mappings = get_attach_mapping(parsed.row, parsed.column)
        opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)
        pickers
            .new(opts, {
                prompt_title = "Find File: " .. search_name,
                finder = finders.new_oneshot_job(find_command, opts),
                previewer = get_custom_previwer(opts, parsed.row),
                sorter = conf.file_sorter(opts),
            })
            :find()
        return true
    end
end

return M
