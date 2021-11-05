---
title: zcomet
description: Fast, Simple Zsh Plugin Manager
image: https://raw.githubusercontent.com/agkozak/zcomet-media/main/CometDonati.jpg
---

Did you ever dream of having a clean-looking `.zshrc` and still getting to the first prompt quickly? Are you tired of tortured syntax and [deferred initialization voodoo](https://github.com/romkatv/zsh-bench/tree/874e3650489538bb14e1000370240520f61de346#deferred-initialization)? Whether you are new to Zsh or a seasoned user, `zcomet` can be a convenient and efficient way to manage plugins.

A plugin manager has a few basic requirements:

  * Cloning plugin repositories
  * Updating plugins
  * Sourcing plugin initialization scripts
  * Managing `FPATH`

A good plugin manager should also handle completions intelligently (`compinit` and `compdef`) and compile scripts (especially the completions dump file). `zcomet` does all this and more. If you were to write a very careful `.zshrc` that did all of these things without using a plugin manager, it could potentially be very fast, but it would be long, complex, and hard to manage. In `zcomet`, it would be as simple as

```sh
# Load zcomet
source /path/to/zcomet.zsh

# Load some plugins
zcomet load author1/plugin1
zcomet load author2/plugin2
zcomet load author3/plugin3

# Load completions
zcomet compinit
```

Surely there must be a lot of overhead from having `zcomet` do the work for you? Actually, shell startup with `zcomet` is so efficient that it will feel as if you are not even using a plugin manager:

![Latencies in Milliseconds](https://raw.githubusercontent.com/agkozak/zcomet-media/main/latencies.png)

*Many thanks to Roman Perepelitsa for sharing his [`zsh-bench`](https://github.com/romkatv/zsh-bench) benchmarking utility.*

## TABLE OF CONTENTS

- [A sample `.zshrc`](#a-sample-zshrc)
- [The most basic subcommands](#the-most-basic-subcommands)
  + [`load`](#load)
  + [`compinit`](#compinit)
- [Other subcommands that you might use in your `.zshrc`](#other-subcommands-that-you-might-use-in-your-zshrc)
  + [`snippet`](#snippet)
  + [`trigger`](#trigger)
  + [`fpath`](#fpath)
- [`zcomet` at the command line](#zcomet-at-the-command-line)
  + [`update`](#update)
  + [`self-update`](#self-update)
  + [`list`](#list)
  + [`help`](#help)
  + [`unload`](#unload)
  + [`compile`](#compile)

## A sample `.zshrc`

```sh
# Clone zcomet if necessary
if [[ ! -f ${ZDOTDIR:-${HOME}}/.zcomet/bin/zcomet.zsh ]]; then
  git clone https://github.com/agkozak/zcomet.git ${ZDOTDIR:-${HOME}}/.zcomet/bin
fi

# Source zcomet.zsh
source ${ZDOTDIR:-${HOME}}/.zcomet/bin/zcomet.zsh

# Load a prompt
zcomet load agkozak/agkozak-zsh-prompt

# Load some plugins
zcomet load agkozak/zsh-z
zcomet load ohmyzsh plugins/gitfast

# Load a code snippet - no need to download an entire repo
zcomet snippet https://github.com/jreese/zsh-titles/blob/master/titles.plugin.zsh

# Lazy-load some plugins
zcomet trigger zhooks agkozak/zhooks
zcomet trigger zsh-prompt-benchmark romkatv/zsh-prompt-benchmark

# Lazy-load Prezto's archive module without downloading all of Prezto's
# submodules
zcomet trigger --no-submodules archive unarchive lsarchive \
    prezto modules/archive

# It is good to load these popular plugins last, and in this order:
zcomet load zsh-users/zsh-syntax-highlighting
zcomet load zsh-users/zsh-autosuggestions

# Run compinit and compile its cache
zcomet compinit
```

## The most basic subcommands

### `load`

Almost every `.zshrc` will use `zcomet load`. It clones a plugin repository from GitHub (if it has not already been cloned), compiles its scripts, adds one of its directories to `FPATH`, adds any `bin/` subdirectory to `PATH`, and sources script(s). If the plugin appears to be Prezto-style, `zcomet load` autoloads functions in its `functions/` subdirectory. The syntax can be as simple as

    zcomet load author/plugin

A fuller description of the command would be

    zcomet load [--no-submodules] author/plugin[@branch|@tag|@commit] [directory] [script1] [script2] ...

So if you wanted to use Oh-My-Zsh's `gitfast` plugin, you would enter

    zcomet load ohmyzsh plugins/gitfast

(The repository `ohmyzsh/ohmyzsh` is so frequently used that `zcomet` allows you to employ the shorthand `ohmyzsh` for it; you can also use `prezto` for `sorin-ionescu/prezto`). `plugins/gitfast` is the subdirectory within the Oh-My-Zsh repository. You do not need to specify which script to `load`; `zcomet` will guess correctly.

If you did need to specify a script or scripts -- if it would not be obvious to `zcomet` what you wanted -- you can do so:

    zcomet load ohmyzsh lib clipboard.zsh git.zsh

That command will clone Oh-My-Zsh if necessary, go to its `lib/` subdirectory, and clone the `clipboard.zsh` and `git.zsh` scripts. You can specify as many scripts as you like.

If you need to clone a specific branch of a plugin repository, you may do so thus:

    zcomet load author/plugin@branch

`@tag` and `@commit` are equally valid.

Finally, some repositories include Git submodules that you may not need. For example, you might be using Prezto's `archive` module:

    zcomet load prezto modules/archive

When you clone Prezto, though, it installs a great number of external plugins. If you do not need them, just enter

    zcomet load --no-submodules prezto modules/archive

`zcomet load` also supports local plugins. A local plugin is a directory that is structured exactly like a plugin you would clone from GitHub or elsewhere, but it does not have to be a Git repository. All you need to do is to specify where that directory is. Note that the path to your local plugin must start either with a `/` or with something that Zsh will expand to be a slash (i.e., no relative paths):

    zcomet load /path/to/local_plugin1
    zcomet load ~/path/to/local_plugin2

### `compinit`

Another command that will appear in almost any `.zshrc` is `zcomet compinit`; completions are one of the most popular features of Zsh. Why use `zcomet compinit` and not the built-in `autoload -Uz compinit; compinit`? `zcomet compinit` will catch any `compdef` declarations that are made too early and run them later. It also makes sure that your dump file is intelligently named and compiled.

## Other subcommands that you might use in your `.zshrc`

### `snippet`

If you simply want to download and source a file without cloning a whole repository (and not all scripts are in Git repositories), you may use `zcomet snippet`:

    zcomet snippet URL

The URL should point to raw code and not a pretty HTML display of it, but there are convenient exceptions. Any `github.com` URL will be translated into its raw code equivalent, so

    zcomet snippet https://github.com/jreese/zsh-titles/blob/master/titles.plugin.zsh

really executes

    zcomet snippet https://raw.githubusercontent.com/jreese/zsh-titles/master/titles.plugin.zsh

There is also the `OMZ::` shorthand for Oh-My-Zsh (borrowed from Zinit):

    zcomet snippet OMZ::plugins/git/git.plugins.zsh

That commands downloads and sources Oh-My-Zsh's Git aliases without cloning the whole `ohmyzsh/ohmyzsh` repository -- a great time-saver if you do not need the whole thing.

You can also specify local snippets:

    zcomet snippet /path/to/script.zsh

### `trigger`

`zcomet trigger` is a lazy-loading command (written in imitation of Zinit's `trigger-load` subcommand) that saves time at shell startup by *not* loading plugins; they are initialized later when particular commands are run:

    zcomet [--no-submodules] [trigger1] [trigger2] ... author/plugin[@branch|@tag|@commit] [directory] [script1] [script2] ...

The first time `zcomet` sees a `trigger` declaration, it clones the plugin in question, but it does not `load` it. On all subsequent runs, it merely observes names of the trigger functions that will cause the plugin to be loaded. It is only when a trigger is actually run that the plugin is truly loaded and the requested command run. So, for example,

    zcomet trigger extract x ohmyzsh plugins/extract

makes it so that there are two functions, `extract` and `x`. If either of those functions is run, Oh-My-Zsh's `extract` plugin is loaded and either `extract` or its alias `x` is run.

### `fpath`

On rare occasions you might want to clone a plugin but only add one of its directories to `FPATH` (without doing anything else). For example, if you like to use Zsh's built-in `promptinit` system for prompt switching, and you like my [agkozak-zsh-prompt](https://github.com/agkozak/agkozak-zsh-prompt) prompt, you could load it thus:

    zcomet fpath agkozak/agkozak-zsh-prompt
    autoload promptinit; promptinit
    prompt agkozak-zsh-prompt

But most of us do not use prompt-switching, and it is much easier just to enter

    zcomet load agkozak/agkozak-zsh-prompt

Like `load` and `trigger`, `fpath` has a `--no-submodules` option.

## `zcomet` at the command line

You can use any of the commands I have just described at the command line. I know I frequently load plugins on the fly. There are, however, some useful `zcomet` commands that you are unlikely to use in you `.zshrc` but which are helpful at the command line.

### `update`

`zcomet update` updates all cloned repositories and re-downloads all remote snippets.

### `self-update`

`zcomet self-update` updates `zcomet` itself. You will have to have installed `zcomet` as a Git repository for this to work.

### `list`

`zcomet list` displays all loaded plugins, sourced snippets, `FPATH` elements added with `zcomet fpath`, and triggers (triggers disappear once they are used and become loaded plugins).

### `help`

Displays basic help.

### `unload`

Unloads a plugin if it has an [unload function](https://github.com/agkozak/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc#4-unload-function). The implementation is still very basic but functional.

### `compile`

You will not normally have to use `zcomet compile`, as `zcomet` tries to compile all the appropriate files, but `zcomet compile` will compile a script with `zcompile -R` and autoloadable functions with `zcompile -Uz`.

**TO BE CONTINUED.**

*Copyright &copy; 2021 Alexandros Kozak*
