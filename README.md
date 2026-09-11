# Editor

This is a small text editor I wrote for myself. The design goals are roughly:

- Small and simple, so I can make modifications with understanding.
- Fast, unless it conflicts too much with the previous point.
- Preserve the nice parts of my Emacs experience.

If you want to make this editor yours, there's two options:

1) Use a binary build and customize `editor.config`. There's a few templates you can start with.

2) Modify the code and compile your own build. See building from source section below.
   The editor is written in Jai, which is not publicly available yet, but should be out soon.

## Building from source

Make a debug build with:

```
jai [-x64] build.jai
```

The binary releases are compiled with:

```
jai -optimized_debug build.jai - -no-windows-console`
```

The build file contains information about more options.

Tested on Jai version `0.2.030`.

The editor currently runs on Windows and macOS. Linux support coming soon.

## Temporary limitations

The editor is currently in alpha. Bugs may happen. Save often.

### Programming language support

Only C (and a subset of C++), Jai, and GLSL are supported right now.

I plan to add support for Rust, C#, TypeScript and Slang soon.
If you want to add support for a language for yourself, look at the existing `lang_xyz.jai` files.

### Speed

- To help debug tricky parts of the code, expensive paranoid assertions enabled by default.
  They are extremely slow. You can disable these by building with `-no-sanity`.
  They will eventually be disabled by default.

- The parser for indentation and lexers for syntax highlighting need to get faster.
  The editor turns them off for files above 10 megabytes.

Once these are solved, you should be able to view and edit multi-gigabyte files without dropping a frame.

### Misc

- Project search currently shells out to [ripgrep](https://github.com/burntsushi/ripgrep).
  Near-term, more external search tools will be supported (e.g. `git grep`).
  Long-term, project search will be implemented in the editor itself.

- Spawning a process and collecting its output (for compilation or project search) is synchronous for now.

## Contributing

I am not prepared to maintain an open-source project. Feel free to make the editor
yours by changing your version.

However, I might accept the occasional patch, especially if it is a small bugfix.
It is also probably safe to send lexers for more programming languages.

Disingenuous behavior not tolerated.

## Acknowledgements

- Jonathan Blow, for making the Jai programming language.
- [Emacs](https://www.gnu.org/software/emacs/), for showing me how good text editing can be.
- [Emacs](https://www.gnu.org/software/emacs/), for getting slower and buggier over time, making me do this.
- [Focus Editor](https://focus-editor.dev/), with which this editor shares the simplicity philosophy.
  If I had tried it out sooner, I might not have made my own.
- My amazing partner, who tolerated me going off on this tangent instead of doing more important stuff.

## License

The editor is in the public domain under the MIT license. You can do whatever with it. Attribution is appreciated.