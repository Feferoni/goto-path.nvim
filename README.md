# goto-path.nvim

A Neovim plugin for quickly navigating to files from text under the cursor.

## Features

- Parse file paths with line and column numbers (e.g., `file.lua:42:10`)
- Extract paths from various delimiters: `"file"`, `<file>`, `[file]`, `(file)`, `{file}`
- Support environment variables: `$(VAR)/file` or `${VAR}/file`
- Direct file opening when path exists
- Fallback to Telescope fuzzy search (optional)
- Extensible search method system

## Requirements

- Neovim >= 0.8
- Telescope (optional, for fuzzy file search)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'your-username/goto-path.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' }, -- optional
    config = function()
        require('goto-path').setup()
    end
}
```

## Usage

### Commands

**`:OpenFile <path>`** - Open file with optional line and column numbers
```vim
:OpenFile init.lua:42:10
:OpenFile "src/main.lua"
:OpenFile $(HOME)/.config/nvim/init.lua
```

`:OpenFile` uses the global `open_file_opts` from `setup()` (see
[Configuration](#configuration)).

### Functions

**`require('goto-path').goto_file(opts)`** - Navigate to file path under cursor

`opts` is optional. Any keys provided override the global `open_file_opts` set in
`setup()` for that call only (see [Configuration](#configuration)).

```lua
-- Example keybinding
vim.keymap.set('n', 'gf', function()
    require('goto-path').goto_file()
end, { desc = 'Go to file under cursor' })

-- Per-call override: this invocation ignores VCS ignore rules
vim.keymap.set('n', '<leader>gf', function()
    require('goto-path').goto_file({ no_ignore = true })
end, { desc = 'Go to file (no ignore)' })
```

### Supported Path Formats

```lua
init.lua              -- Simple filename
init.lua:42           -- With line number
init.lua:42:10        -- With line and column
"init.lua"            -- Quoted
<init.lua>            -- Angle brackets
[init.lua]            -- Square brackets
(init.lua)            -- Parentheses
{init.lua}            -- Curly braces
$(HOME)/file.lua      -- Environment variables
${HOME}/file.lua      -- Alternative env var syntax
/path/to/file.lua:42  -- Full path with line number
```

## Configuration

```lua
require('goto-path').setup({
    -- Extra root prefixes tried when a path is not found directly.
    prefix_paths = {
        "/home/user/git/dotfiles/",
        "/external_dependencies/",
    },

    -- Global options applied to every open. Per-call opts passed to
    -- goto_file(opts) override these on a per-invocation basis.
    open_file_opts = {
        follow = true,          -- follow symlinks (fd -L)
        no_ignore = false,      -- ignore all ignore files (fd --no-ignore)
        no_ignore_vcs = true,   -- ignore only VCS ignore files (fd --no-ignore-vcs)
        hidden = true,          -- include hidden files (fd --hidden); default true
        ignore_file = vim.env.XDG_CONFIG_HOME .. '/fd/ignore', -- fd --ignore-file <path>
    },
})
```

### Option precedence

Options are merged low-to-high, so the most specific value wins:

```
built-in defaults  <  setup({ open_file_opts })  <  goto_file(opts) per call
```

Built-in defaults are `{ follow = true, no_ignore = true, no_ignore_vcs = false }`.
`:OpenFile` uses the global `open_file_opts` (it takes no per-call opts).

### open_file_opts and the fd fallback

When a path is not found directly (or via `prefix_paths`) and Telescope is
available, the fallback search runs `fd`/`fdfind`. `open_file_opts` maps to fd
flags as follows:

| Option          | fd flag                     | Effect                                        |
| --------------- | --------------------------- | --------------------------------------------- |
| `hidden`        | `--hidden`                  | Include dotfiles (added unless set to `false`) |
| `no_ignore`     | `--no-ignore`               | Ignore **all** ignore files (`.gitignore`, `.ignore`, `.fdignore`) |
| `no_ignore_vcs` | `--no-ignore-vcs`           | Ignore **only** VCS ignore files (`.gitignore`) |
| `follow`        | `-L`                        | Follow symlinks                               |
| `ignore_file`   | `--ignore-file <path>`      | Apply a custom ignore file (skipped with a warning if unreadable) |

Notes:

- `--no-ignore` is a superset of `--no-ignore-vcs`. If `no_ignore = true`, then
  `no_ignore_vcs` is redundant.
- To respect a curated ignore file while bypassing `.gitignore` (mirroring a
  typical Telescope grep setup), use `no_ignore = false`, `no_ignore_vcs = true`,
  and set `ignore_file`.
- The plain `find` fallback (used only when neither `fd` nor `fdfind` exists) does
  not support these flags and ignores `open_file_opts`.

## Architecture

The plugin is organized into modular components:

- **parser.lua** - Parses file paths, extracts delimiters, handles environment variables
- **navigator.lua** - Core navigation logic with extensible search methods
- **telescope_navigator.lua** - Telescope integration (loaded only if Telescope is available)

### Adding Custom Search Methods

```lua
local navigator = require('goto-path.navigator')

-- Add custom search method
navigator.add_search_method(function(parsed, opts)
    -- parsed contains: path, file_name, row, column
    -- Return true if file was opened, false otherwise

    local full_path = parsed:get_full_path()
    -- Your custom search logic here

    return false  -- Return true if successful
end)
```

## Testing

Run tests with:
```bash
make test
```

## License

MIT
