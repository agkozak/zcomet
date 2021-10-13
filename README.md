# `zcomet` - Fast, Simple Zsh Plugin Manager

<p align="center">
    <img src="img/logo.png">
</p>

[![MIT License](img/mit_license.svg)](https://opensource.org/licenses/MIT)
![ZSH version 4.3.11 and higher](img/zsh_4.3.11_plus.svg)
[![GitHub stars](https://img.shields.io/github/stars/agkozak/zcomet.svg)](https://github.com/agkozak/zcomet/stargazers)

`zcomet` is a Zsh plugin manager that gets you to the prompt quickly without having to use a cache. Its goal is to be simple and convenient without slowing you down. It succeeds in keeping latencies down to the levels you would expect if you were not even using a plugin manager:

![Latencies in Milliseconds](https://raw.githubusercontent.com/agkozak/zcomet-media/main/latencies.png)

*See [Notes on Benchmarks](#notes-on-benchmarks) below.*

`zcomet` is still in the initial phases of its development. As I make changes and add features, I will explain them in the [News](#news) section.

## Table of Contents

- [News](#news)
- [Example `.zshrc`](#example-zshrc)
- [Dynamic Named Directories](#dynamic-named-directories)
- [Directory Customization](#directory-customization)
- [Commands and Arguments](#commands-and-arguments)
  + [`load`](#load-repository-name-subdirectory-file1-file2-)
  + [`fpath`](#fpath-repository-name-subdirectory)
  + [`trigger`](#trigger-trigger-name-arguments)
  + [`snippet`](#snippet-snippet)
  + [`update`](#update)
  + [`list`](#list)
  + [`compinit`](#compinit)
  + [`compile`](#compile)
  + [`help`](#help)
  + [`self-update`](#self-update)
  + [`unload`](#unload-repository-name)
- [Options](#options)
  + [`--no-submodules`](#--no-submodules)
- [Standards Compliance](#standards-compliance)
- [Notes on Benchmarks]
- [TODO](#todo)

## News

- October 13, 2021
    + I have adopted [@romkatv](https://github.com/romkatv)'s [zsh-bench](https://github.com/romkatv/zsh-bench) benchmarks as a standard for measuring performance.
    + `zcomet` no longer `zcompiles` rc files, and the default behavior of `zcomet compinit` is merely to run `compinit` while specifying a sensibly named cache file (again, props to **@romkatv** for suggesting these changes).

<details>
    <summary>Older news</summary>

- October 4, 2021
    + `zcomet` now fetches Git submodules by default. If you do not need them, be sure to save yourself time by using the [`--no-submodules`](#--no-submodules) option with `load`, `fpath`, or `trigger`.
- September 30, 2021
    + `zcomet` now defers running `compdef` calls until after `zcomet compinit` has been run.
- September 28, 2021
    + `zcomet` now autoloads functions in a `functions/` directory before sourcing a Prezto-style module.
- September 27, 2021
    + `zcomet` now looks for the `bin/` subdirectory in the root directory of the repository, not in the directory where the sources plugin files reside.
- September 21, 2021
    + I have opted to have named directories assigned only at the repository level. Also, if there is more than one repository with the same name (e.g., `author1/zsh-tool` and `author2/zsh-tool`), neither directory is given a name (to prevent mistakes from happening).
- September 20, 2021
    + `zcomet` plugins are now assigned [dynamic named directories](#dynamic-named-directories). This feature was inspired by Marlon Richert's [Znap](https://github.com/marlonrichert/zsh-snap).
- September 18, 2021
    + `zcomet` directories are now specified using `zstyle`; [see below](#directory-customization).
    + The `load` command will now add a plugin's `bin/` subdirectory, if it has one, to the `PATH`.
- September 17, 2021
    + `zcommet trigger` now always makes sure that the repository it needs has already been cloned, meaning that you will never have to wait for files to be downloaded when you use a defined trigger.
- September 16, 2021
    + `zcomet list` now reflects `FPATH` elements added using the `fpath` command.
    + New command: `zcomet compinit` runs `compinit` and compiles its cache for you.
- September 15, 2021
    + `zcomet` will store your plugins and snippets in `${ZDOTDIR}`, if you have set that variable and if `${HOME}/.zcomet` does not already exist. Props to @mattjamesdev.
- September 13, 2021
    + The `snippet` command now supports any URL that points to raw Zsh code (not HTML) via HTTP or HTTPS. It will translate `github.com` addresses into their `raw.githubusercontent.com` equivalents. You may still use the `OMZ::` shorthand for Oh-My-Zsh code.
</details>

## Example `.zshrc`

```sh
# Clone zcomet if necessary
if [[ ! -f ${ZDOTDIR:-${HOME}}/.zcomet/bin/zcomet.zsh ]]; then
  command git clone https://github.com/agkozak/zcomet.git ${ZDOTDIR:-${HOME}}/.zcomet/bin
fi

source ${ZDOTDIR:-${HOME}}/.zcomet/bin/zcomet.zsh

# Load a prompt
zcomet load agkozak/agkozak-zsh-prompt

# Load some plugins
zcomet load agkozak/zsh-z
zcomet load ohmyzsh plugins/gitfast

# Load a code snippet
zcomet snippet https://github.com/jreese/zsh-titles/blob/master/titles.plugin.zsh

# Lazy-load some plugins
zcomet trigger zhooks agkozak/zhooks
zcomet trigger zsh-prompt-benchmark romkatv/zsh-prompt-benchmark

# Lazy-load Prezto's archive module without downloading all of Prezto's
# submodules
zcomet trigger --no-submodules archive unarchive lsarchive \
    sorin-ionescu/prezto modules/archive

# Run compinit and compile its cache
zcomet compinit
```

## Directory Customization

`zcomet` will store plugins, snippets, and the like in `~/.zcomet` by default. If you have set `$ZDOTDIR`, then `zcomet` will use `${ZDOTDIR}/.zcomet` instead. You can also specify a custom home directory for `zcomet` thus:

    zstyle ':zcomet:*' home-dir ~/path/to/home_dir

Make sure to do that before you start loading code.

In the home directory there will usually be a `/repos` subdirectory for plugins and a `/snippets` subdirectory for snippets, but you may name your own locations:

    zstyle ':zcomet:*' repos-dir ~/path/to/repos_dir
    zstyle ':zcomet:*' snippets-dir ~/path/to/snippets_dir

I recommend cloning the `agkozak/zcomet` repository to a `/bin` subdirectory in your `zcomet` home directory (e.g., `~/.zcomet/bin`), as in the [example `.zshrc`](#example-zshrc) above.

## Dynamic Named Directories

If you `load`, `fpath`, or `trigger` a number of plugins, `zcomet` will give them dynamic directory names. For the [example `.zshrc`](https://github.com/agkozak/zcomet/tree/develop#example-zshrc) above, the following named directories would be created:

    ~[agkozak-zsh-prompt]
    ~[ohmyzsh]
    ~[zhooks]
    ~[zsh-prompt-benchmark]
    ~[zsh-z]

You will also have `~[zcomet-bin]`, the directory in which the `zcomet.zsh` script resides.

Try typing `cd ~[` and press `<TAB>` to see a list of dynamic directories. This new feature should be particularly useful to people who write plugins and prompts -- it makes it very easy to get to the code.

This feature was inspired by Marlon Richert's [Znap](https://github.com/marlonrichert/zsh-snap).

## Commands and Arguments

### `load` repository-name \[subdirectory\] \[file1\] \[file2\] ...

`load` is the most commonly used command; it clones a GitHub repository (if it has not already been downloaded), adds its root directory (or `functions/` subdirectory, if it exists) to `FPATH`, adds any `bin/` subdirectory to `PATH`, and sources a file or files. The simplest example is:

    zcomet load agkozak/zsh-z

The common repositories `ohmyzsh/ohmyzsh` and `sorin-ionescu/prezto` can be abbreviated as `ohmyzsh` and `prezto`, respectively. `zcomet` uses simple principles to choose which init file to source (in this case, `/path/to/agkozak/zsh-z/zsh-z.plugin.zsh` is the obvious choice).

A subdirectory of a repository can be specified:

    zcomet load ohmyzsh plugins/gitfast

loads Oh-My-Zsh's useful `gitfast` plugin. If a specific file or files in a subdirectory should be sourced, they can be specified:

    zcomet load ohmyzsh lib git.zsh
    zcomet load sindresorhus/pure async.zsh pure.zsh

If there are autoloadable functions in a Prezto-style `functions/` directory, they will be automatically autoloaded.

A specific branch, tag, or commit of a repository can be checked out using the following syntax:

    zcomet load author/repo@branch

(`@tag` and `@commit` are equally valid.)

`load` is the command used for loading prompts.

*NOTE: If the repository that `load` is cloning has submodules, consider whether or not you really need them. Using the [`--no-submodules`](#--no-submodules) option after `load` can save a lot of time during installation and updating.*

### `fpath` repository-name \[subdirectory\]

`fpath` will clone a repository and add one of its directories to `FPATH`. Unlike `load`, it does not source any files. Also, you must be very specific about which subdirectory is to be added to `FPATH`; `zcomet fpath` does not try to guess. If you wanted to use the agkozak-zsh-prompt with `promptinit`, you could run

    zcomet fpath agkozak/agkozak-zsh-prompt
    autoload promptinit; promptinit
    prompt agkozak-zsh-prompt

(But if you are not intending to switch prompts, it is much easier just to use `zcomet load agkozak/agkozak-zsh-prompt`.)

*NOTE: If the repository that `fpath` is cloning has submodules, consider whether or not you really need them. Using the [`--no-submodules`](#--no-submodules) option after `fpath` can save a lot of time during installation and updating.*

### `trigger` trigger-name \[arguments\]

`trigger` lazy-loads plugins, saving time when you start the shell. If you specify a command name, a Git repository, and other optional arguments (the same arguments that get used for `load`), the plugin will be loaded and the command run only when the command is first used:

    zcomet trigger zhooks agkozak/zhooks

for example, creates a function called `zhooks` that loads the `zhooks` plugin and runs the command `zhooks`. It takes next to no time to create the initial function, so this is perfect for commands that you do not instantly and constantly use. If there is more than one command that should trigger the loading of the plugin, you can specify each separately:

    zcomet trigger extract ohmyzsh plugins/extract
    zcomet trigger x ohmyzsh plugins/extract

or save time by listing a number of triggers before the repository name:

    zcomet trigger extract x ohmyzsh plugins/extract

`trigger` always checks to make sure that the repository it needs has been already cloned; if not, it clones it. The goal is for triggers to take almost no time to load when they are actually run.

*NOTE: If the repository that `trigger` is cloning has submodules, consider whether or not you really need them. Using the [`--no-submodules`](#--no-submodules) option after `trigger` can save a lot of time during installation and updating.*

This feature was inspired by [Zinit](https://github.com/zdharma/zinit)'s `trigger-load` command.

### `snippet` snippet

`snippet` downloads a script (when necessary) and sources it:

    zcomet snippet OMZ::plugins/git/git.plugins.zsh

This example will download Oh-My-Zsh's `git` aliases without cloning the whole Oh-My-Zsh repository -- a great time-saver.

`zcomet` will translate `github.com` URLs into their raw code `raw.githubusercontent.com` equivalents. For example,

    zcomet snippet https://github.com/jreese/zsh-titles/blob/master/titles.plugin.zsh

really executes

    zcomet snippet https://raw.githubusercontent.com/jreese/zsh-titles/master/titles.plugin.zsh

For snippets that are not hosted by GitHub, you will want to make sure that the URL you use points towards raw code, not a pretty HTML display of it.

### `update`

`zcomet update` downloads updates for any plugins or snippets that have been downloaded in the past and re-`source`s any active plugins or snippets.

### `list`

`zcomet list` displays any active plugins, added `FPATH` elements, snippets, and triggers. As you use the triggers, you will see them disappear as triggers and reappear as loaded plugins.

### `compinit`

Runs Zsh's `compinit` command, which is necessary if you want to use command line completions. `compinit`'s cache is then stored in a file in the `$HOME` directory (or in `$ZDOTDIR`, if you have defined it) starting with `.zcompdump_` and ending with the version number of the `zsh` you are using, e.g., `.zcompdump_5.8`. `zcomet` compiles the cache for you.

Like other plugin managers and frameworks, `zcomet` defers running `compdef` calls until `zcomet compinit` runs, which means that you can load a plugin full of `compdefs` (e.g., `zcomet load ohmyzsh plugins/git`) even before `zcomet compinit` and its completions will still work.

A simple `zcomet compinit` should always get the job done, but if you need to rename the cache file ("dump file"), you can do so thus:

    zstyle ':zcomet:compinit' dump-file /path/to/dump_file

If you need to specify other options to `compinit`, you can do it this way:

    zstyle 'zcomet:compinit' arguments -i   # I.e., run `compinit -i'

But it is safest to stick to the default behavior. An incorrectly configured `compinit` can lead to your completions being broken or unsafe code being loaded.

### `compile`

Compiles a script or scripts if there is no corresponding wordcode (`.zwc`) file or if a script is newer than its `.zwc`.

### `help`

Displays a help screen.

### `self-update`

Updates `zcomet` itself. Note that `zcomet` must have been installed as a cloned Git repository for this to work.

### `unload` \[repository-name\]

Unloads a plugin that has an [unload function](https://github.com/zdharma/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc#4-unload-function). The implementation is still very basic.

## Options

### `--no-submodules`

By default, if a repository has submodules, `zcomet` will fetch them whenever the `load`, `fpath`, `trigger`, or `update` commands are issued. For example, I use [Prezto's `archive` module](https://github.com/sorin-ionescu/prezto/tree/master/modules/archive), but I don't need all of the external prompts in the `prompt` module, so I use `zcomet`'s `--no-submodules` option:

    zcomet load --no-submodules sorin-ionescu/prezto modules/archive

Not fetching the submodules saves a good deal of time when cloning the repository.

## Standards Compliance

I am a great admirer of [Sebastian Gniazdowski's principles for plugin development](https://github.com/zdharma/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc), and I have incorporated most of his suggestions into `zcomet`:

* Standardized `$0` handling
* Support for `functions/` directories
* Support for `bin/` directories
* Support for `unload` functions
* `zsh_loaded_plugins`: a plugin manager activity indicator
* `ZPFX`: global parameter with PREFIX for `make`, `configure`, etc.
* `PMSPEC`: global parameter holding the plugin manager’s capabilities

## Notes on Benchmarks

When I started this project, I was happy to discover that I scored well on benchmarks that measure `zsh -lic "exit"`. Roman Perepelitsa [has argued eloquently](https://github.com/romkatv/zsh-bench) that such benchmarks are misleading, and that we should instead pay attention to comparative latencies that affect user experience. The graph above compares the performance of [a well constructed `.zshrc` with no plugin manager](https://github.com/romkatv/zsh-bench/blob/master/configs/diy%2B%2B/skel/.zshrc) against [an easy-to-make `zcomet .zshrc`](https://github.com/romkatv/zsh-bench/blob/master/configs/zcomet/skel/.zshrc).

## TODO

* Supply prettier output
* Provide more helpful error messages
* Allow user to update just one repository or snippet
* Improve the `unload` command
* Allow the loading of repositories not on GitHub
* Support for `ssh://` and `git://`

*Copyright (C) 2021 Alexandros Kozak*
