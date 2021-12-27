local v = vim.v
local bo = vim.bo
local opt = vim.opt
local fn = vim.fn
local M = {}

-- config.match_the_close_pattern

---@return string content the content of the first nonblank line of the folding region
function M.content(config)
   local line_num = v.foldstart
   local content = fn.getline(line_num)
   local indent_num = fn.indent(line_num)

   local comment_signs = fn.split(bo.commentstring, '%s')
   for i, p in ipairs(comment_signs) do
      comment_signs[i] = vim.pesc(p)
   end
   if vim.tbl_isempty(comment_signs) then table.insert(comment_signs, '') end

   do -- Remove all fold markers from string.
   -- if config.remove_fold_markers then
      for _, fdm in ipairs( opt.foldmarker:get() ) do
         content = content:gsub(fdm..'%d*', '')
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
         indent_num = fn.indent(line_num)
      end
   end

   if config.sections.left[1] == 'content' then
      if indent_num > 1 then
         -- Replace indentation with 'fill_char's.
         content = content:gsub('^%s+',
            string.rep(config.fill_char, indent_num - 1)..' ')
      end
   else
      content = content:gsub('^%s*', ' ')  -- Strip all indentation.
   end

   content = content:gsub('%s*$', '')

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

   content = content..' '

   -- Replace all tabs with spaces with respect to %tabstop.
   content = content:gsub('\t', string.rep(' ', bo.tabstop))

   -- Exchange all occurrences of multiple spaces inside the text with
   -- 'fill_char', like this:
   --    "//      Text"  ->  "// ==== Text"
   for blank_substr in content:gmatch( '%s%s%s+' ) do
      content = content:gsub(
         blank_substr,
         ' '..string.rep(config.fill_char, #blank_substr - 2)..' ',
         1)
   end

   return content
end

function M.number_of_folded_lines()
   return (v.foldend - v.foldstart + 1)..' lines'
end

function M.percentage()
   local fold_size = v.foldend - v.foldstart + 1  -- The number of folded lines.
   local pnum = math.floor(100 * fold_size / vim.api.nvim_buf_line_count(0))
   return (pnum < 10 and ' ' or '') .. pnum .. '%'
end

local function unknown_section(_, custom_section)
   -- return custom_section
   if vim.is_callable(custom_section) then
      return custom_section()
   else
      return custom_section
   end
end

return setmetatable(M, { __index = unknown_section })
