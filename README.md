# Floor Placer

Place floor and landfill ghosts by dragging a selection.

![Screenshot](https://raw.githubusercontent.com/xaviershay/factorio-mod-floor-placer/main/floor-placer-1.jpg)

## Compatibility

It should "just work" with mods that add other blueprintable tiles, such as Space Exploration.

## TODO

* More use in anger.
* Integrate with undo/redo.
* Make an icon.
* Consider using item icon in selection tool, so it looks similar to placing tiles normally.
* Option to auto-place tile ghosts when you walk over them.
* Space Exploration platform ghosts can be placed on planets, which doesn't match behaviour if
  placing from inventory. Just a style thing though, the placement will fail
  when a bot tries to construct it.
* Code cleanup.

## Development

I use the Factorio Modding Tool Kit extension for VSCode, with a custom mod
directory. On windows, link this repo into your mod directory with a symbolic
link (a shortcut won't work):

> Start-Process powershell -Verb runAs # If command doesn't have sufficient privileges
> New-Item -Path $MODDIR\floor-placer -ItemType SymbolicLink -Value $REPODIR

Package and release using the "publish" command provided by FMTK .. though it's
not working for me at the moment (issue:
https://github.com/justarandomgeek/vscode-factoriomod-debug/issues/158).

Current terrible release by hand process:

* Bump version number in `info.json`
* Edit `changelog.txt` to taste
* Copy/paste all files into a new directory including version number e.g. `floor-placer_0.3.1`
* Delete `.vscode`, `.git*`, and `*.zip` files
* Zip the directory
* Upload directly to mod portal