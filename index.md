---
title: zcomet - Fast, Simple Zsh Plugin Manager
description: Get to the prompt quickly with a clean-looking zcomet .zshrc!
hide_description: true
image: https://raw.githubusercontent.com/agkozak/zcomet-media/main/CometDonati.jpg
cover: true
---

Do you ever dream of having a clean-looking `.zshrc` and enjoying swift Zsh startup times? Are you tired of tortured syntax and the frustrations of deferred initialization voodoo? Whether you are new to Zsh or a seasoned user, `zcomet` can be a convenient and efficient way to manage plugins.

A plugin manager performs a few basic tasks:

  * Cloning plugin repositories
  * Updating plugins
  * Sourcing plugin initialization scripts
  * Managing `FPATH`

A really good plugin manager should also handle completions intelligently (`compinit` and `compdef`) and compile scripts (especially the completions dump file). `zcomet` does all this and more. If you were to write a very careful `.zshrc` that did all of these things without using a plugin manager, it could potentially be very fast, but it would be long, complex, and hard to manage. With `zcomet`, it is as simple as

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

[![Latencies in Milliseconds](https://raw.githubusercontent.com/agkozak/zcomet-media/main/latencies.png)](https://github.com/romkatv/zsh-bench/tree/75e9fa15b9993983ed55c1584770b78215305149#plugin-managers)

*Many thanks to Roman Perepelitsa for sharing his [`zsh-bench`](https://github.com/romkatv/zsh-bench) benchmarking utility.*

[Try `zcomet` now!](https://github.com/agkozak/zcomet)

*Copyright &copy; 2021-2022 Alexandros Kozak*
