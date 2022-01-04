local v = vim.v
local bo = vim.bo
local opt = vim.opt
local fn = vim.fn
local M = {}

---@return string content modified first nonblank line of the folded region
function M.content(config)
   ---The number of the line from which produces content for the fold string:
   ---first non-blank line.
   ---@type number
   local line_num = v.foldstart
   ---The content of the 'content' section.
   ---@type string
   local content = fn.getline(line_num)

   ---The list of comment characters for the current buffer, where all Lua magic
   ---characters are escaped.
   ---@type string[]
   local comment_signs = fn.split(bo.commentstring, '%s')
   ---List with comment signs lengths.
   ---@type number[]
   local comment_signs_len = {}
   if vim.tbl_isempty(comment_signs) then
      comment_signs[1] = ''
      comment_signs_len[1] = 0
   else
      for i, p in ipairs(comment_signs) do
         comment_signs[i] = vim.pesc(p)
         comment_signs_len[i] = fn.strdisplaywidth(p)
      end
   end

   -- Remove all fold markers from string.
   if config.remove_fold_markers then
      for _, fdm in ipairs( opt.foldmarker:get() ) do
         content = content:gsub(vim.pesc(fdm)..'%d*', '')
      end

      -- Remove all comment signs from the end of the string.
      for i = #comment_signs, 1, -1 do  -- Iterate backward from the end of the list.
         content = content:gsub('%s*'..comment_signs[i]..'%s*$', '')
      end
   end

   -- If after removimg fold markers and comment signs we get blank line,
   -- take next nonblank.
   if content:match('^%s*$') then
      line_num = fn.nextnonblank(v.foldstart + 1)
      if line_num ~= 0 and line_num <= v.foldend then
         content = fn.getline(line_num)
      end
   end

   if not vim.tbl_isempty(config.stop_words) then
      for _, w in ipairs(config.stop_words) do
         content = content:gsub(w, '')
      end
   end

   if config.add_close_pattern then  -- Add matchup pattern
      local last_line = fn.getline(v.foldend)
      last_line = last_line:gsub(comment_signs[1]..'.*$', '')
      last_line = vim.trim(last_line)
      for _, p in ipairs(config.matchup_patterns) do
         if content:find( p[1] ) and last_line:find( p[2] ) then

            local ellipsis = (#p[1] == 1) and '...' or ' ... '

            local comment_str = content:match('%s*'..comment_signs[1]..'.*$')

            if comment_str then
               local cs = content:match('%s*'..comment_signs[1]..'%s*')
               local comment_str_new = comment_str:gsub(
                  vim.pesc(cs),
                  ' '..config.fill_char:rep(#cs > 2 and #cs-2 or 1)..' ')

               content = content:gsub(
                  vim.pesc(comment_str),
                  ellipsis..last_line..comment_str_new)
                  -- ellipsis..p[2]..comment_str_new)
            else
               content = content..ellipsis..last_line
               -- content = content..ellipsis..p[2]
            end

            break
         end
      end
   end

   if config.comment_signs then
      for i, sign in ipairs(comment_signs) do
         content = content:gsub(sign,
            (config.comment_signs == 'spaces' and string.rep(' ', comment_signs_len[i]))
            or
            (config.comment_signs == 'delete' and '')
         )
      end
   end

   if config.sections.left[1] == 'content' and config.keep_indentation then
      local opening_blank_substr = content:match('^%s%s+')
      if opening_blank_substr then
         content = content:gsub(
            opening_blank_substr,
            config.fill_char:rep(#opening_blank_substr - 1)..' ',
            1)
      end
   elseif config.sections.left[1] == 'content' then
      content = content:gsub('^%s*', '') -- Strip all indentation.
   else
      content = content:gsub('^%s*', ' ')
   end

   content = content:gsub('%s*$', '')
   content = content..' '

   -- Replace all tabs with spaces with respect to %tabstop.
   content = content:gsub('\t', string.rep(' ', bo.tabstop))

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
