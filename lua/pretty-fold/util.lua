local M = {}

---Raise a warning message
---@param msg string
function M.warn(msg)
   vim.schedule(function()
      vim.notify('[pretty-fold.nvim] '..msg, vim.log.levels.WARN)
   end)
end

---Raise a warning if an old option label was used and replace it with a new one.
---@param config table
---@param config_is_fdm_specific boolean
---@param old string
---@param new string
---@return table config
function M.config_deprecated(config, config_is_fdm_specific, old, new)
   local status = false

   if config_is_fdm_specific then
      for _, k in ipairs(vim.tbl_keys(config)) do
         if vim.tbl_contains( vim.tbl_keys(config[k]), old) then
            config[k][new], config[k][old] = config[k][old], nil
            status = true
         end
      end
   else
      if vim.tbl_contains( vim.tbl_keys(config), old) then
         config[new], config[old] = config[old], nil
         status = true
      end
   end

   if status then
      M.warn( string.format(
         'pretty-fold.nvim: "%s" option was renamed to "%s" and old name will be removed soon',
          old, new
      ))
   end

   return config
end

---Returns the comment signs table with all duplicate items removed.
---@param t table
---@return table
function M.unique_comment_signs(t)
   if #t < 3 then return t end
   local ut = { t[1] }
   for i = 2, #t do
      local seen = false
      for j = 1, #ut do
         if ut[j] == t[i]
            -- or
            -- type(t[i]) == 'table' and type(ut[j]) == 'table'
            -- and t[i][1] == ut[j][1]
            -- and t[i][2] == ut[j][2]
         then
            seen = true
            break
         end
      end
      if not seen then table.insert(ut, t[i]) end
   end
   return ut
end

return M
