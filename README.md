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

### Functions

**`require('goto-path').goto_file()`** - Navigate to file path under cursor

```lua
-- Example keybinding
vim.keymap.set('n', 'gf', function()
    require('goto-path').goto_file()
end, { desc = 'Go to file under cursor' })
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
    prefix_paths = {
            "/home/user/git/dotfiles/",
            "/external_dependencies/",
        },
})
```

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
