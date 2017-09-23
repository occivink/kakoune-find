# kakoune-find

[kakoune](http://kakoune.org) plugin to search for a pattern in all open buffers. Works similarly to `grep.kak`, but does not operate on files.

[![demo](https://asciinema.org/a/138327.png)](https://asciinema.org/a/138327)

## Install

Add `find.kak` to your autoload dir: `~/.config/kak/autoload/`, or source it manually.

## Usage

Call the `find` command. You can specify the pattern as the first argument, otherwise the content of the main selection will be used. From the `*find*` buffer you can jump to the actual match using `<ret>`.

## License

Unlicense
