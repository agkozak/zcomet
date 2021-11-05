---
title: zcomet
description: Fast, Simple Zsh Plugin Manager
image: https://raw.githubusercontent.com/agkozak/zcomet-media/main/CometDonati.jpg
---

`zcomet` is a Zsh plugin manager that gets you to the prompt quickly. Its goal is to be simple and convenient without slowing you down. It succeeds in keeping latencies down to the level you would expect if you were not even using a plugin manager:

![Latencies in Milliseconds](https://raw.githubusercontent.com/agkozak/zcomet-media/main/latencies.png)

The speed difference can be undetectable, but the improved convenience is noteworthy. A `zcomet` configuration can be as simple as:

```sh
source /path/to/zcomet.zsh

zcomet load author1/plugin1
zcomet load author2/plugin2
zcomet load author3/plugin3

zcomet compinit
```

Those lines will clone repositories, source scripts, update your `FPATH` and `PATH`, and load the Zsh completion system.

## Sample `.zshrc`

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

# Load a code snippet - no need to download an entire repo
zcomet snippet https://github.com/jreese/zsh-titles/blob/master/titles.plugin.zsh

# Lazy-load some plugins
zcomet trigger zhooks agkozak/zhooks
zcomet trigger zsh-prompt-benchmark romkatv/zsh-prompt-benchmark

# Lazy-load Prezto's archive module without downloading all of Prezto's
# submodules
zcomet trigger --no-submodules archive unarchive lsarchive \
    sorin-ionescu/prezto modules/archive

# It is good to load these popular plugins last, and in this order:
zcomet load zsh-users/zsh-syntax-highlighting
zcomet load zsh-users/zsh-autosuggestions

# Run compinit and compile its cache
zcomet compinit
```

*Copyright &copy; 2021 Alexandros Kozak*
