local warn = require("pretty-fold.util").warn

warn('preview module have been moved into separate plugin:: https://github.com/anuvyklack/fold-preview.nvim')

---@class Void Void has eveything and nothing

---@type Void
local void = setmetatable({}, {
   __index = function(self) return self end,
   __newindex = function() end,
   __call = function() end
})

return void
