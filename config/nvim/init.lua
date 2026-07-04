-- Basic settings
vim.opt.number = true
vim.opt.termguicolors = true
vim.opt.background = "dark"

-- Load pywal colors
local wal_colors = vim.fn.expand("~/.cache/wal/colors-nvim.lua")
if vim.fn.filereadable(wal_colors) == 1 then
  dofile(wal_colors)
end
