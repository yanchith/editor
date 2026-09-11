# Editor

(Yes, it needs a name.)

This is a small text editor I wrote for myself. The design goals are roughly:

- Small and simple, so I can make modifications with understanding.
- Fast, unless it conflicts too much with the previous point.
- Preserve the nice parts of my Emacs experience.

The editor is currently in alpha. Bugs and infrequent crashes may happen. Save often.

If you want to make this editor yours, there's two options:

1) Use a binary build and customize `editor.config`. There's a few templates you can start with, like
   `editor.config.sublime` or `editor.config.vscode`.
   Currently, this lets you set a theme and keybinds. It will eventually let you do more.

2) Modify the code and compile your own build. The catch is that the editor is written in Jai,
   which is not publicly available yet, but should be out before too long.

## Temporary limitations

### Programming language support

Currently, only C (and a subset of C++), Jai, and GLSL are supported.
I plan to add support for Rust, C#, Typescript, HLSL and Slang pretty soon.
If you want to add support for a language for yourself, look at the existing `lang_xyz.jai` files.

### Speed

- To help debug issues in tricky parts of the code, binary releases have expensive paranoid assertions enabled.
  They asserts are extremely slow. You can disable these with `-no-sanity`.

- The parser for indentation and lexers for syntax highlighting need to get faster.
  The editor turns them off for files above 10 megabytes.

- Search needs to be faster.

Once these are solved, you should be able to view and edit multi-gigabyte files without dropping a frame.

### Misc

- Project and directory search currently shells out to ripgrep. You need to have the `rg` command installed on your system.
  Near-term, I'd like to support more external search tools (e.g. `git grep`).
  Long-term, project search will be implemented in the editor itself.

- Spawning a process and collecting its output (for compilation or project search) is synchronous for now.

## Building from source

Run `jai [-x64] build.jai` for a debug build.

The binary release was compiled with `jai -optimized_debug build.jai - -no-windows-console`

Run `jai build.jai - -help` to get the full list of options.
Some particularly useful ones are `-no-windows-console` and `-no-sanity`.

Tested on Jai version `beta 0.2.030, 2 July 2026`.

The editor currently runs on Windows and macOS. Linux support coming soon.

## Contributing

I am not prepared to maintain an open-source project. Feel free to make the editor
yours by changing your version.

However, I might accept the occasional patch, especially if it is a small bugfix.
It is also probably safe to send lexers for more programming languages.

Disingenuous behavior not tolerated.

## Acknowledgements

- Jonathan Blow, for making the Jai programming language.
- Emacs, for showing me how good text editing can be.
- Emacs, for getting slower and buggier over the years, making me do this.
- Focus editor, from which I borrowed the lexer-per-programming language approach.
  Also, if I had tried it out sooner, I might not have made my own.
- My amazing partner, who tolerated me going off on this tangent instead of doing more important stuff.

## License

The editor is in the public domain under the MIT license. You can do whatever with it. Attribution is appreciated, though.