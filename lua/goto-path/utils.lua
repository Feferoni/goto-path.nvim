local M = {}

M.getLnum = function(lnum, bufnr)
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_count then
        return math.max(1, math.min(lnum, line_count))
    end
    return 0
end

M.getCnum = function(lnum, cnum, bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)
    if lines and lines[1] then
        return math.max(0, math.min(string.len(lines[1]), cnum) - 1)
    else
        return 0
    end
end

return M
