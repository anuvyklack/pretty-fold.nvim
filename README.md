# Pretty Fold

**Pretty Fold** is a lua plugin for Neovim which has two separate features:
* Framework for easy foldtext customization. Filetype specific and foldmethod
  specific configuration is supported.
* Folded region preview (*like in QtCreator*).

https://user-images.githubusercontent.com/13056013/148261501-56677c8f-24a7-4c45-b008-8c1863bf06e8.mp4

## Instalation and quickstart

Instalation and setup expample with [packer](https://github.com/wbthomason/packer.nvim):

```lua
use{ 'anuvyklack/pretty-fold.nvim',
   config = function()
      require('pretty-fold').setup{}
      require('pretty-fold.preview').setup_keybinding()
   end
}
```

## Foldtext configuration

pretty-fold.nvim comes with the following defaults:

```lua
{
   fill_char = '•',
   sections = {
      left = {
         'content',
      },
      right = {
         ' ', 'number_of_folded_lines', ': ', 'percentage', ' ',
         function(config) return config.fill_char:rep(3) end
      }
   },

   remove_fold_markers = true,

   -- Keep the indentation of the content of the fold string.
   keep_indentation = true,

   -- Possible values:
   -- "delete" : Delete all comment signs from the fold string.
   -- "spaces" : Replace all comment signs with equal number of spaces.
   -- false    : Do nothing with comment signs.
   comment_signs = 'spaces',

   -- List of patterns that will be removed from content foldtext section.
   stop_words = {
      '@brief%s*', -- (for cpp) Remove '@brief' and all spaces after.
   },

   add_close_pattern = true,
   matchup_patterns = {
      { '{', '}' },
      { '%(', ')' }, -- % to escape lua pattern char
      { '%[', ']' }, -- % to escape lua pattern char
      { 'if%s', 'end' },
      { 'do%s', 'end' },
      { 'for%s', 'end' },
   },
}
```

### `sections`

The main part. Contains two tables: `config.sections.left` and
`config.sections.right` which content will be left and right aligned
respectively. Each of them can contains [service sections](#service-sections),
strings and functions that return string. All functions accept config table as
an argument.

#### Service sections

The strings from the table below will be expanded according to the table.

| Item                       | Expansion |
| -------------------------- | --------- |
| `'content'`                | The content of the first non-blank line of the folded region, somehow modified according to other options. |
| `'number_of_folded_lines'` | The number of folded lines. |
| `'percentage'`             | The percentage of the folded lines out of the whole buffer. |

### `fill_char`

Character used to fill the space between the left and right sections.

### `remove_fold_markers`

Remove foldmarkers from the `content` section.

### `keep_indentation`

Keep the indentation of the content of the fold string.

### `comment_signs`

What to do with commnet signs.

| Option     | Description |
| ---------- | ----------- |
| `'delete'` | delete all comment signs from the foldstring |
| `'spaces'` | replace all comment signs with equal number of spaces |
| `false`    | do nothing with comment signs |

### `stop_words`

Patterns that will be removed from the `content` section.

### `matchup_patterns`

The list with patterns where each item is a list with two items: open and
close patterns.

If `config.add_close_pattern` option is set to `true`, and the opening pattern is
found in first non-blank line of the folded region the close pattern will be
added after ellipsis (`...`). Like this:

![image](https://user-images.githubusercontent.com/13056013/148240635-6945810b-4a44-4d77-b136-ac2e2f062669.png)

![image](https://user-images.githubusercontent.com/13056013/148230674-e87cdaa4-a92d-45f4-bf4a-d48ba306608b.png)

<!-- ![image](https://user-images.githubusercontent.com/13056013/148239208-ca2a2217-94c4-40c0-a7f1-9c44708e2c2c.png) -->

The comment substring in foldtext is correctly handled on close pattern adding.

![image](https://user-images.githubusercontent.com/13056013/148239141-190246a9-2333-42a1-a2e5-ec59e374f741.png)

![image](https://user-images.githubusercontent.com/13056013/148239172-f1d13021-b2c5-43ee-930b-aaeb8d079a1b.png)

If `comment_signs = 'spaces'` is set, the output will be

![image](https://user-images.githubusercontent.com/13056013/148242150-ac25edd9-b9b4-4ebe-b567-a38ff67d76c8.png)

### Examples

```lua
require('pretty-fold').setup{
   keep_indentation = false,
   fill_char = '•',
   sections = {
      left = {
         '+', function() return string.rep('-', vim.v.foldlevel) end,
         ' ', 'number_of_folded_lines', ':', 'content',
      },
      right = nil
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


### Setup for particular filetype

This plugin provides to setup functions.

The first one
```lua
require('pretty-fold').setup(config: table)
```
sets global `foldtext` option.

But if you want to setup filetype specific `foldext` use the secons one

```lua
require('pretty-fold').ft_setup(filtype: string, config: table)
```

This function should be called for every buffer of the desired filtype, but
this plugin doesn't provides any autocommands to do this because Neovim (and
Vim) has much more convinient mechanist to do this: **`after/ftplugin` directory**.
To setup foldext with pretty-fold.nvim plugin only for, for expample, C++ files
add to the file (on Linux)

```sh
$HOME/.config/nvim/after/ftplugin/cpp.lua
```

the next content:

```lua
require('pretty-fold').ft_setup('cpp', {
   stop_words = {
      '@brief%s*', -- remove '@brief' and all spaces after from foldtext
   },
   -- your other settings
})
```

### Foldmethod specific configuration

The pretty-fold.nvim plugin supports different configuration for different
[foldmethods](https://neovim.io/doc/user/options.html#'foldmethod').
For this pass the configuration table for a particular foldmethod as a value to
the key named after foldmethod.

It is allowed to have one unlabeled global config table for all foldmethods and
tune only desired options in foldmethod specific config table. All options that
doesn't have value in foldmethod config table will be taken from global config
table.

Example:

```lua
require('pretty-fold').setup({
    {...}, -- global config table for all Foldmethods
    marker = { comment_signs = 'spaces' },
    expr   = { comment_signs = false },
})
```

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
require('pretty-fold.preview').setup_keybinding('h') --  choose'h' or 'l' key
```

**Warning:** Only `h` or `l` keys can be passed to this function, any other will cause an error.

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
