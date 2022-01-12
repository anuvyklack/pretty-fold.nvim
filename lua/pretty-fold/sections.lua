local util = require('pretty-fold.util')
local v = vim.v
local bo = vim.bo
local opt = vim.opt
local fn = vim.fn
local M = {}

---@param config? table
---@return string content modified first nonblank line of the folded region
function M.content(config)
   ---The content of the 'content' section.
   ---@type string
   local content = fn.getline(v.foldstart)

   ---The list of comment characters for the current buffer, where all Lua magic
   ---characters are escaped.
   ---@type string[]
   local comment_signs = fn.split(bo.commentstring, '%s')

   -- Add additional comment signs from 'config.comment_signs' table.
   if not vim.tbl_isempty(config.comment_signs) then
      comment_signs = {
         #comment_signs == 1 and unpack(comment_signs) or comment_signs,
         unpack(config.comment_signs)
      }
   end

   -- comment_signs = vim.tbl_flatten(comment_signs)
   comment_signs = util.unique_comment_signs(comment_signs)
   table.sort(comment_signs, function(a, b)
      if type(a) == "table" then a = a[1] end
      if type(b) == "table" then b = b[1] end
      return #a > #b and true or false
   end)

   ---Table  with comment signs lengths.
   ---@type number[]
   local comment_signs_len = vim.deepcopy(comment_signs)
   for i, p in ipairs(comment_signs) do
      if type(p) == "string" then
         -- comment_signs_len[i] = fn.strdisplaywidth(p)
         comment_signs_len[i] = #p
         comment_signs[i] = vim.pesc(p)
      elseif type(p) == "table" then
         -- comment_signs_len[i][1] = fn.strdisplaywidth(p[1])
         -- comment_signs_len[i][2] = fn.strdisplaywidth(p[2])
         comment_signs_len[i][1] = #p[1]
         comment_signs_len[i][2] = #p[2]

         comment_signs[i][1] = vim.pesc(p[1])
         comment_signs[i][2] = vim.pesc(p[2])
      end
   end

   -- if vim.tbl_isempty(comment_signs) then
   --    comment_signs[1] = ''
   --    comment_signs_len[1] = 0
   -- end

   if config.remove_fold_markers then
      local fdm = opt.foldmarker:get()[1]
      content = content:gsub(vim.pesc(fdm)..'%d*', ''):gsub('%s+$', '')
   end

   -- If after removimg fold markers and comment signs we get blank line,
   -- take next nonblank.
   local blank = content:match('^%s*$') and true or false
   local only_comment_sign = false
   if not blank then
      for _, c in ipairs(comment_signs) do
         if content:match( table.concat{'^%s*', c[1] or c, '$'} ) then
            only_comment_sign = true
            break
         end
      end
   end
   if blank or only_comment_sign then
      local line_num = fn.nextnonblank(v.foldstart + 1)
      if line_num ~= 0 and line_num <= v.foldend then
         if config.process_comment_signs or blank then
            content = fn.getline(line_num)
         else
            local add_line = vim.trim(fn.getline(line_num))
            for _, c in ipairs(comment_signs) do
               add_line = add_line:gsub( table.concat{'^', c[1] or c, '%s*'}, '')
            end
            content = table.concat({ content, ' ', add_line })
         end
      end
   end

   if not vim.tbl_isempty(config.stop_words) then
      for _, w in ipairs(config.stop_words) do
         content = content:gsub(w, '')
      end
   end

   if config.add_close_pattern then  -- Add matchup pattern
      local last_line = fn.getline(v.foldend)

      for _, c in ipairs(vim.tbl_flatten(comment_signs)) do
         last_line = last_line:gsub(c..'.*$', '')
      end

      last_line = vim.trim(last_line)
      for _, p in ipairs(config.matchup_patterns) do
         if content:find( p[1] ) and last_line:find( p[2] ) then

            local ellipsis = (#p[1] == 1) and '...' or ' ... '

            local comment_str = nil
            for _, c in ipairs(comment_signs) do
               comment_str = content:match( table.concat{'%s*', c[1] or c, '.*$'})
            end

            if comment_str then
               content = content:gsub(
                  vim.pesc(comment_str),
                  table.concat{ ellipsis, last_line, comment_str }
               )
            else
               content = table.concat{ content, ellipsis, last_line }
               -- content = table.concat{ content, ellipsis, p[2] }
            end

            break
         end
      end
   end

   if config.process_comment_signs then
      for i, sign in ipairs(comment_signs) do
         content = content:gsub(sign,
            (config.process_comment_signs == 'spaces' and string.rep(' ', comment_signs_len[i]))
            or
            (config.process_comment_signs == 'delete' and '')
         )
      end
   end

   -- Replace all tabs with spaces with respect to %tabstop.
   content = content:gsub('\t', string.rep(' ', bo.tabstop))

   if config.keep_indentation then
      local opening_blank_substr = content:match('^%s%s+')
      if opening_blank_substr then
         content = content:gsub(
            opening_blank_substr,
            config.fill_char:rep(#opening_blank_substr - 1)..' ',
            -- config.fill_char:rep(fn.strdisplaywidth(opening_blank_substr) - 1)..' ',
            1)
      end
   elseif config.sections.left[1] == 'content' then
      content = content:gsub('^%s*', '') -- Strip all indentation.
   else
      content = content:gsub('^%s*', ' ')
   end

   content = content:gsub('%s*$', '')
   content = content..' '

   -- Exchange all occurrences of multiple spaces inside the text with
   -- 'fill_char', like this:
   -- "//      Text"  ->  "// ==== Text"
   for blank_substr in content:gmatch( '%s%s%s+' ) do
      content = content:gsub(
         blank_substr,
         ' '..string.rep(config.fill_char, #blank_substr - 2)..' ',
         1)
   end

   return content
end

---@return string
function M.number_of_folded_lines()
   return string.format('%d lines', v.foldend - v.foldstart + 1)
end

---@return string
function M.percentage()
   local fold_size = v.foldend - v.foldstart + 1  -- The number of folded lines.
   local pnum = math.floor(100 * fold_size / vim.api.nvim_buf_line_count(0))
   return (pnum < 10 and ' ' or '') .. pnum .. '%'
end

return setmetatable(M, {
   __index = function(_, custom_section)
      return custom_section
   end
})
