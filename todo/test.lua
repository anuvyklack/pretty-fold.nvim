local keymap = {}

local mode = 'n'
local lhs = 'h'


---Normalize key sequence.
---@param keys string
---@return string
keymap.normalize = function(keys)
  vim.api.nvim_set_keymap('t', '<Plug>(cmp.utils.keymap.normalize)', keys, {})
  for _, map in ipairs(vim.api.nvim_get_keymap('t')) do
    if keymap.equals(map.lhs, '<Plug>(cmp.utils.keymap.normalize)') then
      return map.rhs
    end
  end
  return keys
end

---Get map
---@param mode string
---@param lhs string
---@return table
keymap.get_map = function(mode, lhs)
  lhs = keymap.normalize(lhs)

  for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
    if keymap.equals(map.lhs, lhs) then
      return {
        lhs = map.lhs,
        rhs = map.rhs or '',
        expr = map.expr == 1,
        callback = map.callback,
        noremap = map.noremap == 1,
        script = map.script == 1,
        silent = map.silent == 1,
        nowait = map.nowait == 1,
        buffer = true,
      }
    end
  end

  for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
    if keymap.equals(map.lhs, lhs) then
      return {
        lhs = map.lhs,
        rhs = map.rhs or '',
        expr = map.expr == 1,
        callback = map.callback,
        noremap = map.noremap == 1,
        script = map.script == 1,
        silent = map.silent == 1,
        nowait = map.nowait == 1,
        buffer = false,
      }
    end
  end

  return {
    lhs = lhs,
    rhs = lhs,
    expr = false,
    callback = nil,
    noremap = true,
    script = false,
    silent = true,
    nowait = false,
    buffer = false,
  }
end

---Register keypress handler.
keymap.listen = function(mode, lhs, callback)
  lhs = keymap.normalize(keymap.to_keymap(lhs))

  local existing = keymap.get_map(mode, lhs)
  local id = string.match(existing.rhs, 'v:lua%.cmp%.utils%.keymap%.set_map%((%d+)%)')
  if id and keymap.set_map.callbacks[tonumber(id, 10)] then
    return
  end

  local bufnr = existing.buffer and vim.api.nvim_get_current_buf() or -1
  local fallback = keymap.fallback(bufnr, mode, existing)
  keymap.set_map(bufnr, mode, lhs, function()
    if mode == 'c' and vim.fn.getcmdtype() == '=' then
      fallback()
    else
      callback(lhs, misc.once(fallback))
    end
  end, {
    expr = false,
    noremap = true,
    silent = true,
  })
end

---Fallback
keymap.fallback = function(bufnr, mode, map)
  return function()
    if map.expr then
      local fallback_expr = string.format('<Plug>(cmp.u.k.fallback_expr:%s)', map.lhs)
      keymap.set_map(bufnr, mode, fallback_expr, function()
        return keymap.solve(bufnr, mode, map).keys
      end, {
        expr = true,
        noremap = map.noremap,
        script = map.script,
        nowait = map.nowait,
        silent = map.silent and mode ~= 'c',
      })
      vim.api.nvim_feedkeys(keymap.t(fallback_expr), 'itm', true)
    elseif not map.callback then
      local solved = keymap.solve(bufnr, mode, map)
      vim.api.nvim_feedkeys(solved.keys, solved.mode, true)
    else
      map.callback()
    end
  end
end

---Solve
keymap.solve = function(bufnr, mode, map)
  local lhs = keymap.t(map.lhs)
  local rhs = map.expr and (map.callback and map.callback() or vim.api.nvim_eval(keymap.t(map.rhs))) or keymap.t(map.rhs)

  if map.noremap then
    return { keys = rhs, mode = 'itn' }
  end

  if string.find(rhs, lhs, 1, true) == 1 then
    local recursive = string.format('<Plug>(cmp.u.k.recursive:%s)', lhs)
    keymap.set_map(bufnr, mode, recursive, lhs, {
      noremap = true,
      script = map.script,
      nowait = map.nowait,
      silent = map.silent and mode ~= 'c',
    })
    return { keys = keymap.t(recursive) .. string.gsub(rhs, '^' .. vim.pesc(lhs), ''), mode = 'itm' }
  end
  return { keys = rhs, mode = 'itm' }
end
