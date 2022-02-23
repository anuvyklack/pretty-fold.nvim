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

   -- Trim redundant spaces from the beggining and the end if any.
   if not vim.tbl_isempty(comment_signs) then
      for i = 1, #comment_signs do
         comment_signs[i] = vim.trim(comment_signs[i])
      end
   end

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

   if type(config.add_close_pattern) == "boolean"  -- Add matchup pattern
      and config.add_close_pattern
   then
      local str = content
      local found_patterns = {}
      for _, pat in ipairs(config.matchup_patterns) do
         local found = {}

         local start, stop = nil, 0
         while stop do
            start, stop = str:find(pat[1], stop + 1)
            if start then
               table.insert(found, { start = start, stop = stop, pat = pat[1] })
            end
         end

         local num_op = #found  ---number of opening patterns
         if num_op > 0 then
            start, stop = nil, 0
            while stop do
               start, stop = str:find(pat[2], stop + 1)
               if start then
                  table.insert(found, { start = start, stop = stop, pat = pat[2] })
               end
               -- If number of closing patterns become equal to number of openning
               -- patterns, then break.
               if #found - num_op == num_op then break end
            end
         end

         if num_op > 0 and num_op ~= #found then
            table.sort(found, function(a, b)
               return a.start < b.start and true or false
            end)

            local str_parts = {}
            table.insert(str_parts, str:sub(1, found[1].start - 1))
            for i = 1, #found - 1 do
               table.insert(str_parts, str:sub(found[i].stop + 1, found[i+1].start - 1))
            end
            table.insert(str_parts, str:sub(found[#found].stop + 1))
            str = table.concat(str_parts, ' ')

            ---previous, current, next
            local p, c, n = nil, 1, 2
            while true do
               if found[c].pat == pat[1] and found[n].pat == pat[2] then
                  table.remove(found, n)
                  table.remove(found, c)
                  if p then
                     c, n = p, c
                     p = p > 1 and p-1 or nil
                  end
               else
                  c, n = c + 1, n + 1
                  p = (p or 0) + 1
               end
               if n > #found then break end
            end
         end

         for _, f in ipairs(found) do
            table.insert(found_patterns, { pat = pat, pos = f.start })
         end
      end
      table.sort(found_patterns, function(a, b)
         return a.pos < b.pos and true or false
      end)

      if not vim.tbl_isempty(found_patterns) then
         local comment_str = ''
         for _, c in ipairs(comment_signs) do
            local c_start = content:find(table.concat{'%s*', c[1] or c, '.*$'})

            if c_start then
               comment_str = content:sub(c_start)
               content = content:sub(1, c_start - 1)
               break
            end
         end

         local ellipsis = #found_patterns[#found_patterns].pat[2] == 1 and '...' or ' ... '

         str = { content, ellipsis }
         for i = #found_patterns, 1, -1 do
            table.insert(str, found_patterns[i].pat[2])
         end
         table.insert(str, comment_str)
         content = table.concat(str)
      end
   elseif config.add_close_pattern == 'last_line' then
      if config.add_close_pattern then  -- Add matchup pattern
         local last_line = fn.getline(v.foldend)

         for _, c in ipairs(vim.tbl_flatten(comment_signs)) do
            last_line = last_line:gsub(c..'.*$', '')
         end

         last_line = vim.trim(last_line)
         for _, p in ipairs(config.matchup_patterns) do
            if content:find( p[1] ) and last_line:find( p[2] ) then

               local ellipsis = (#p[2] == 1) and '...' or ' ... '

               local comment_str = ''
               for _, c in ipairs(comment_signs) do
                  local c_start = content:find(table.concat{'%s*', c[1] or c, '.*$'})

                  if c_start then
                     comment_str = content:sub(c_start)
                     content = content:sub(1, c_start - 1)
                     break
                  end
               end

               content = table.concat{ content, ellipsis, last_line, comment_str }
               break
            end
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
   for blank_substr in content:gmatch('%s%s%s+') do
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
   local folded_lines = v.foldend - v.foldstart + 1  -- The number of folded lines.
   local total_lines = vim.api.nvim_buf_line_count(0)
   local pnum = math.floor(100 * folded_lines / total_lines)
   if pnum == 0 then
      pnum = tostring(100 * folded_lines / total_lines):sub(2, 3)
   elseif pnum < 10 then
      pnum = ' '..pnum
   end
   return pnum .. '%'
end

return setmetatable(M, {
   __index = function(_, custom_section)
      return custom_section
   end
})
