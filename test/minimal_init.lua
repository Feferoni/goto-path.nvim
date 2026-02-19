vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.cmd([[set packpath=/tmp/nvim/site]])

local package_root = '/tmp/nvim/site/pack'
local install_path = package_root .. '/packer/start/plenary.nvim'

if vim.fn.isdirectory(install_path) == 0 then
    vim.fn.system({ 'git', 'clone', 'https://github.com/nvim-lua/plenary.nvim', install_path })
end

vim.cmd([[runtime! plugin/plenary.vim]])
vim.opt.runtimepath:append('.')
