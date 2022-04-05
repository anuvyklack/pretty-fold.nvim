# Pretty Fold

**Pretty Fold** is a lua plugin for Neovim which has two separate features:
* Framework for easy foldtext customization. Filetype specific and foldmethod
  specific configuration is supported.
* Folded region preview (*like in QtCreator*).

https://user-images.githubusercontent.com/13056013/148261501-56677c8f-24a7-4c45-b008-8c1863bf06e8.mp4

## Installation and quickstart

Installation and setup example with [packer](https://github.com/wbthomason/packer.nvim):

```lua
use{ 'anuvyklack/pretty-fold.nvim',
   config = function()
      require('pretty-fold').setup()
      require('pretty-fold.preview').setup()
   end
}
```

## Foldtext configuration

Pretty-fold.nvim comes with the following defaults
(the description of each option is below):

```lua
config = {
   sections = {
      left = {
         'content',
      },
      right = {
         ' ', 'number_of_folded_lines', ': ', 'percentage', ' ',
         function(config) return config.fill_char:rep(3) end
      }
   },
   fill_char = '•',

   remove_fold_markers = true,

   -- Keep the indentation of the content of the fold string.
   keep_indentation = true,

   -- Possible values:
   -- "delete" : Delete all comment signs from the fold string.
   -- "spaces" : Replace all comment signs with equal number of spaces.
   -- false    : Do nothing with comment signs.
   process_comment_signs = 'spaces',

   -- Comment signs additional to the value of `&commentstring` option.
   comment_signs = {},

   -- List of patterns that will be removed from content foldtext section.
   stop_words = {
      '@brief%s*', -- (for C++) Remove '@brief' and all spaces after.
   },

   add_close_pattern = true, -- true, 'last_line' or false

   matchup_patterns = {
      {  '{', '}' },
      { '%(', ')' }, -- % to escape lua pattern char
      { '%[', ']' }, -- % to escape lua pattern char
   },

   ft_ignore = { 'neorg' },
}
```

### `sections`

The main part. Contains two tables: `config.sections.left` and
`config.sections.right` which content will be left and right aligned
respectively.  Each of them can contain names of the
[components](#built-in-components) and functions that returns string.

#### Built-in components

The strings from the table below will be expanded according to the table.

| Item                       | Expansion |
| -------------------------- | --------- |
| `'content'`                | The content of the first non-blank line of the folded region, somehow modified according to other options. |
| `'number_of_folded_lines'` | The number of folded lines. |
| `'percentage'`             | The percentage of the folded lines out of the whole buffer. |

#### Custom functions

All functions accept config table as an argument, so if you would like to pass
any arguments into your custom function, place them into the config table which
you pass to `setup` function and then you can access them inside your function,
like this:

```lua
require('pretty-fold').setup {
   custom_function_arg = 'Hello from inside custom function!',
   sections = {
      left = {
         function(config)
            return config.custom_function_arg
         end
      },
   }
}
```

![image](https://user-images.githubusercontent.com/13056013/149224663-aad3e2cd-411a-4a8d-b2a4-a821795dfade.png)

### `fill_char`
**default**: `'•'`

Character used to fill the space between the left and right sections.

### `remove_fold_markers`
**default**: `true`

Remove foldmarkers from the `content` component.

### `keep_indentation`
**default**: `true`

Keep the indentation of the content of the fold string.

### `process_comment_signs`

What to do with comment signs:
**default**: `spaces`

| Option     | Description |
| ---------- | ----------- |
| `'delete'` | delete all comment signs from the foldstring |
| `'spaces'` | replace all comment signs with equal number of spaces |
| `false`    | do nothing with comment signs |

### `comment_signs`
**default**: `{}`

Table with comment signs additional to the value of `&commentstring` option.
Add additional comment signs only when you really need them.  Otherwise, they
give computational overhead without any benefits.

Example for Lua. Default `&commentstring` value for Lua is: `'--'`.

```lua
comment_signs = {
    { '--[[', '--]]' }, -- multiline comment
}
```

Example for C++.  Default `&commentstring` value for C++ is: `{ '/*', '*/' }`

```lua
comment_signs = { '//' }
```

### `stop_words`

**default**: `'@brief%s*'` (for C++) Remove '@brief' and all spaces after.

[Lua patterns](https://www.lua.org/manual/5.1/manual.html#5.4.1) that will be
removed from the `content` section.

### `add_close_pattern`
**default:** `true`

If this option is set to `true` for all opening patterns that will be found in
the first non-blank line of the folded region, all corresponding closing
elements will be added after ellipsis.  (The synthetical string with matching
closing elements will be constructed).

If it is set to `last_line`, the last line content (without comments) will be
added after the ellipsis .  This behavior was the first algorithm I
implemented, but turns out it is not always relevant.  For some languages (at
least for all lisps) this does not work.  Since it is already written and if
someone like this behavior, I keep this option to choose.

### `matchup_patterns`

The list with matching elements.
Each item is a list itself with two items: opening
[lua pattern](https://www.lua.org/manual/5.1/manual.html#5.4.1) and
close string which will be added if oppening pattern is found.

Examples for lua (Lua patterns are explained with railroad diagrams):

```lua
matchup_patterns = {
   -- ╟─ Start of line ──╭───────╮── "do" ── End of line ─╢
   --                    ╰─ WSP ─╯
   { '^%s*do$', 'end' }, -- "do ... end" blocks

   -- ╟─ Start of line ──╭───────╮── "do" ──╭───────╮ ─╢
   --                    ╰─ WSP ─╯          ╰─ WSP ─╯
   { '^%s*do%s', 'end' }, -- "do ... end" blocks with comment

   -- ╟─ Start of line ──╭───────╮── "if" ─╢
   --                    ╰─ WSP ─╯
   { '^%s*if', 'end' },

   -- ╟─ Start of line ──╭───────╮── "for" ─╢
   --                    ╰─ WSP ─╯
   { '^%s*for', 'end' },

   -- ╟─ "function" ──╭───────╮── "(" ─╢
   --                 ╰─ WSP ─╯
   { 'function%s*%(', 'end' }, -- "function(" or "function ("

   {  '{', '}' },
   { '%(', ')' }, -- % to escape lua pattern char
   { '%[', ']' }, -- % to escape lua pattern char
},
```

![image](https://user-images.githubusercontent.com/13056013/148240635-6945810b-4a44-4d77-b136-ac2e2f062669.png)

![image](https://user-images.githubusercontent.com/13056013/148230674-e87cdaa4-a92d-45f4-bf4a-d48ba306608b.png)

<!-- ![image](https://user-images.githubusercontent.com/13056013/148239208-ca2a2217-94c4-40c0-a7f1-9c44708e2c2c.png) -->

The comment substring in foldtext is correctly handled on close elements adding.

![image](https://user-images.githubusercontent.com/13056013/148239141-190246a9-2333-42a1-a2e5-ec59e374f741.png)

![image](https://user-images.githubusercontent.com/13056013/148239172-f1d13021-b2c5-43ee-930b-aaeb8d079a1b.png)

If `process_comment_signs = 'spaces'` is set, the output will be

![image](https://user-images.githubusercontent.com/13056013/148242150-ac25edd9-b9b4-4ebe-b567-a38ff67d76c8.png)

### Setup for particular filetype

> :warning: **WARNING**: This functionality is available only in the
> [nightly](https://github.com/anuvyklack/pretty-fold.nvim/tree/nightly)
> branch.
>
> Due to the `foldtext` is a local to window option and for this functionality
> we need it to work as local to buffer option, we have to set desired value
> every time buffer in the window changed.
>
> For this the plugin need to set an autocommand. My research shown that only
> the latest autocommands Lua API suites for this, but it available only in the
> **Neovim 0.7-nightly**. When it will be released the nightly branch will
> become default.
>
> To install the pretty-fold nightly branch with
> [packer](https://github.com/wbthomason/packer.nvim) use next snippet:
>
> ```lua
> use{ 'anuvyklack/pretty-fold.nvim',
>    branch = 'nightly',
>    ...
> }
> ```

This plugin provides two setup functions.

1) The first one setup configuration which will be used for all filetypes for
   which you doesn't set their own configuration.

   ```lua
   require('pretty-fold').setup(config: table)
   ```

2) The second one allows to setup filetype specific configuration:

   ```lua
   require('pretty-fold').ft_setup(filtype: string, config: table)
   ```

#### Example of ready to use foldtext configuration only for lua files

```lua
require('pretty-fold').ft_setup('lua', {
   matchup_patterns = {
      { '^%s*do$', 'end' },  -- do ... end blocks
      { '^%s*do%s', 'end' }, -- do ... end blocks with comment
      { '^%s*if', 'end' },   -- if ... end
      { '^%s*for', 'end' },  -- for
      { 'function%s*%(', 'end' }, -- 'function(' or 'function ('
      {  '{', '}' },
      { '%(', ')' }, -- % to escape lua pattern char
      { '%[', ']' }, -- % to escape lua pattern char
   },
}
```

#### `ft_ignore` options
**default:** `{ 'neorg' }`

Filetypes to be ignored.

`ft_ignore` is a unique option. It exists only in a single copy for all global
and filetype specific configurations. You can pass it in any function
(`setup()` or `ft_setup()`) and all this values will be collected in this one
single value.


### Foldmethod specific configuration

The pretty-fold.nvim plugin supports saparate configuration for different
[foldmethods](https://neovim.io/doc/user/options.html#'foldmethod').
For this pass the configuration table for a particular foldmethod as a value to
the key named after foldmethod.

You can also pass `global` configuration table for all foldmethods and tune
only desired options in foldmethod specific config table. All options that
don't have value in foldmethod config table will be taken from `global` config
table.

Example:

```lua
require('pretty-fold').setup({
    global = {...}, -- global config table for all foldmethods
    marker = { process_comment_signs = 'spaces' },
    expr   = { process_comment_signs = false },
})
```

### Examples

```lua
require('pretty-fold').setup{
   keep_indentation = false,
   fill_char = '•',
   sections = {
      left = {
         '+', function() return string.rep('-', vim.v.foldlevel) end,
         ' ', 'number_of_folded_lines', ':', 'content',
      }
   }
}
```

![image](https://user-images.githubusercontent.com/13056013/148228541-8275f7c7-973a-4cbd-bf9b-4b1ea7e2cc1c.png)

```lua
require('pretty-fold').setup{
   keep_indentation = false,
   fill_char = '━',
   sections = {
      left = {
         '━ ', function() return string.rep('*', vim.v.foldlevel) end, ' ━┫', 'content', '┣'
      },
      right = {
         '┫ ', 'number_of_folded_lines', ': ', 'percentage', ' ┣━━',
      }
   }
}
```

![image](https://user-images.githubusercontent.com/13056013/148228526-980c62fa-71d2-40d0-b91b-439528e8cbce.png)

#### Configuration for C++ to get nice foldtext for Doxygen comments

```lua
require('pretty-fold').ft_setup('cpp', {
   process_comment_signs = false,
   comment_signs = {
      '/**', -- C++ Doxygen comments
   },
   stop_words = {
      -- ╟─ "*" ──╭───────╮── "@brief" ──╭───────╮──╢
      --          ╰─ WSP ─╯              ╰─ WSP ─╯
      '%*%s*@brief%s*',
   },
})
```

![image](https://user-images.githubusercontent.com/13056013/149036027-2fa5d85b-5525-4d54-b69f-07298f2422e3.png)

![image](https://user-images.githubusercontent.com/13056013/149036034-bee3aef5-a5fe-445b-977f-61030c26e4f8.png)

## Preview

I personally don't want to learn a new key combination to open fold preview.
So I tried to create something that would feel natural.

The preview open can be mapped to `h` or `l` key.  This key will be work as
usual until you move cursor somewhere inside folded region.  Then on first
press on this key, the preview floating window will be opened. On second press
fold will be opened and preview will be closed.

A preview window also will be closed on any cursor move, changing mode, or
buffer leaving.

To enable this feature call

```lua
require('pretty-fold.preview').setup {
   key = 'h', -- choose 'h' or 'l' key
}
```

**Warning:** Only `h` or `l` keys can be passed, any other will cause an error.

### Configuration

Available settngs with default values:

```lua
config = {
   key = 'h', -- 'h', 'l' or nil (if you would like to set your own keybinding)

   -- 'none', "single", "double", "rounded", "solid", 'shadow' or table
   -- For explanation see: :help nvim_open_win()
   border = {' ', '', ' ', ' ', ' ', ' ', ' ', ' '},
}
```

### Custom preview mapping

If you would like to create your custom preview mapping check
[lua/pretty-fold/preview.lua](https://github.com/anuvyklack/pretty-fold.nvim/blob/master/lua/pretty-fold/preview.lua)
file. The main function is `show_preview()` which creates preview floating
window and setup autocommands to close it and change its size on scrolling and
vim resizing.


## Additional information

Check ['fillchars'](https://neovim.io/doc/user/options.html#'fillchars')
option.  From lua it can be set the next way:
```lua
vim.opt.fillchars:append('fold:•')
```
