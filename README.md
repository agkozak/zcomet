# `zcomet` - Zsh Plugin Manager

<p align="center">
    <img src="img/logo.png">
</p>

[![MIT License](img/mit_license.svg)](https://opensource.org/licenses/MIT)
![ZSH version 4.3.11 and higher](img/zsh_4.3.11_plus.svg)

`zcomet` is a backwards-compatible Zsh plugin manager that gets you to the prompt quickly without having to use a cache. It began as a series of routines that I used in my dotfiles to source plugins and snippets whenever I was using a version of Zsh that was too old for [Zinit](https://github.com/zdharma/zinit). I was pleasantly surprised to find that my code performs impressively in [Zim's framework benchmark test](https://github.com/zimfw/zsh-framework-benchmark).

`zcomet` is still in the initial phases of its development. I have to implement prettier and more informative messages (you will see some raw Git output), and error handling is very basic at present. I also expect that I will make the occasional change to the command syntax as I move forward.

## Example `.zshrc`

```sh
# Clone zcomet if necessary
if [[ ! -f ${HOME}/.zcomet/bin/zcomet.zsh ]]; then
  command git clone https://github.com/agkozak/zcomet.git ${HOME}/.zcomet/bin
fi

source ~/.zcomet/bin/zcomet.zsh

# Load a prompt
zcomet load agkozak/agkozak-zsh-prompt

# Load some plugins
zcomet load agkozak/zsh-z
zcomet load jreese/zsh-titles
zcomet load ohmyzsh plugins/gitfast

# Lazyload some plugins
zcomet trigger zhooks agkozak/zhooks
zcomet trigger extract x ohmyzsh plugins/extract
zcomet trigger zsh-prompt-benchmark romkatv/zsh-prompt-benchmark

# Load compinit
autoload -Uz compinit
compinit -C -d "${HOME}/.zcompdump_${ZSH_VERSION}"
# Compile compinit's dumpfile to wordcode
zcomet compile "${HOME}/.zcompdump_${ZSH_VERSION}"
```

## Commands and Arguments

### `load` repository-name \[subdirectory\] \[file1\] \[file2\] ...

`load` is the most commonly used command; it clones a GitHub repository (if it has not already been downloaded), adds its root directory (or `/functions/` subdirectory, if it exists) to `FPATH`, and sources a file or files. The simplest example is:

    zcomet load agkozak/zsh-z

The common repositories `ohmyzsh/ohmyzsh` and `sorin-ionescu/prezto` can be abbreviated as `ohmyzsh` and `prezto`, respectively. `zcomet` uses simple principles to choose which init file to source (in this case, `/path/to/agkozak/zsh-z/zsh-z.plugin.zsh` is the obvious choice).

A subdirectory of a repository can be specified:

    zcomet load ohmyzsh plugins/gitfast

loads Oh-My-Zsh's useful `gitfast` plugin. If a specific file or files in a subdirectory should be sourced, they can be specified:

    zcomet load ohmyzsh lib git.zsh
    zcomet load sindresorhus/pure async.zsh pure.zsh

Note that autoloadable functions are not automatically autoloaded yet; you will have to do that explicitly for now.

A specific branch, tag, or commit of a repository can be checked out using the following syntax:

    zcomet load author/name@branch

(`@tag` and `@commit` are equally valid.)

`load` is the command used for loading prompts.

### `fpath` repository-name \[subdirectory\]

`fpath` will clone a repository and add one of its directories to `FPATH`. Unlike `load`, it does not source any files. Also, you must be very specific about which subdirectory is to be added to `FPATH`; `zcomet fpath` does not try to guess. If you wanted to use the agkozak-zsh-prompt with `promptinit`, you could run

    zcomet fpath agkozak/agkozak-zsh-prompt
    autoload promptinit; promptinit
    prompt agkozak-zsh-prompt

(But if you are not intending to switch prompts, it is much easier just to use `zcomet load agkozak/agkozak-zsh-prompt`.)

### `trigger` trigger-name \[arguments\]

`trigger` lazyloads plugins, saving time when you start the shell. If you specify a command name, a Git repository, and other optional arguments (the same arguments that get used for `load`), the plugin will be loaded and the command run only when the command is first used:

    zcomet trigger zhooks agkozak/zhooks

for example, creates a function called `zhooks` that loads the `zhooks` plugin and runs the command `zhooks`. It takes next to no time to create the initial function, so this is perfect for commands that you do not instantly and constantly use. If there is more than one command that should trigger the loading of the plugin, you can specify each separately:

    zcomet trigger extract ohmyzsh plugins/extract
    zcomet trigger x ohmyzsh plugins/extract

or save time by listing a number of triggers before the repository name:

    zcomet trigger extract x ohmyzsh plugins/extract

`trigger` was inspired by Zinit's `trigger-load` command.

### `snippet` snippet

`snippet` downloads a script (when necessary) and sources it:

    zcomet snippet OMZ::plugins/git/git.plugins.zsh

This example will download Oh-My-Zsh's `git` aliases without cloning the whole Oh-My-Zsh repository -- a great time-saver.

For now, only Oh-My-Zsh files are supported, but soon I will include support for any URL.

### `update`

`zcomet update` downloads updates for any plugins or snippets that have been downloaded in the past and re-`source`s any active plugins or snippets.

### `list`

`zcomet list` displays any active plugins, snippets, and triggers. As you use the triggers, you will see them disappear as triggers and reappear as loaded plugins.

### `compile`

`zcompile`s a script or scripts if there is no corresponding wordcode (`.zwc`) file or if a script is newer than its `.zwc`. I strongly recommend that you `zcomet compile` whatever `.zcompdump` file your shell is using, as in the example `.zshrc` above -- it will speed up your load time considerably.

### `help`

Displays a simple help screen.

### `self-update`

Updates `zcomet` itself. Note that `zcomet` must have been installed as a cloned Git repository for this to work.

### `unload` \[repository-name\]

Unloads a plugin that has an [unload function](https://github.com/zdharma/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc#4-unload-function). The implementation is still very basic.

## TODO

* Supply prettier output
* Provide more helpful error messages
* Allow user to update just one repository or snippet
* Improve the `unload` command
* Allow the loading of repositories not on GitHub
* Allow for snippets from any source (not just from Oh-My-Zsh)
* Allow user to clone `trigger` repositories before they are needed

*Copyright (C) 2021 Alexandros Kozak*