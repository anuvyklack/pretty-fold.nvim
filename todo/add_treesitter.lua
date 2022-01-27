local ts_parsers = require('nvim-treesitter/parsers')
local ts_utils = require('nvim-treesitter/ts_utils')

local bufnr = vim.api.nvim_win_get_buf(0)
local root_lang_tree = ts_parsers.get_parser(bufnr)
local root = ts_utils.get_root_for_position(v.foldstart, 1, root_lang_tree)
local node = root:descendant_for_range(v.foldstart, 1, v.foldstart, #fn.getline(v.foldstart))
local text = ts_utils.get_node_text(node, bufnr)

-- -- The same but through official api:
-- local parser = vim.treesitter.get_parser(0) -- vim.o.filetype
-- local tstree = parser:parse()
-- local root = tstree:root()

print(vim.inspect( text ))
