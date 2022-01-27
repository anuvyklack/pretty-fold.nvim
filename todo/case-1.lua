-- Add support for TreeSitter

keymap.set_map(bufnr, mode, fallback, function()
  local lhs = keymap.t(map.lhs)
  local rhs = (function()
    if map.callback then
      return map.callback()
    end
    return vim.api.nvim_eval(keymap.t(map.rhs))
  end)()
  if not map.noremap then
    rhs = keymap.recursive(lhs, rhs)
  end
  return rhs
end, {
  expr = true,
  noremap = map.noremap,
  script = map.script,
  silent = mode ~= 'c',
  nowait = map.nowait,
})
