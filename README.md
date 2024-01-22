# A small goto file plugin
## Requirements
* Telescope
* Maybe my dotfiles for telescope (haven't tested without)

## Function descriptions
Open file with optional linenumber, columnnumber. Will first look if the full path exist and open file directly.
If no direct file is found, it will search in project with telescope.
```
OpenFile fileName/path[:lnum:cnum]
```

Goto_file, will use the current text block under cursor to see if it can resolve the file.
```
require('goto-path').goto_file()
```
