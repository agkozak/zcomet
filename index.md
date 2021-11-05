---
title: zcomet
description: Fast, Simple Zsh Plugin Manager
image: https://raw.githubusercontent.com/agkozak/zcomet-media/main/CometDonati.jpg
---

Did you ever dream of having a clean-looking `.zshrc` and still getting to the first prompt quickly? Are you tired of tortured syntax and [deferred initialization voodoo](https://github.com/romkatv/zsh-bench/tree/874e3650489538bb14e1000370240520f61de346#deferred-initialization)? Whether you are new to Zsh or a seasoned user, `zcomet` can be a convenient and efficient way to manage plugins.

A plugin manager has a few vital tasks:

  * Cloning plugin repositories
  * Updating plugins
  * Sourcing plugin initialization scripts
  * Managing `FPATH`

A good plugin manager should also handle completions intelligently (`compinit` and `compdef`) and compile scripts (especially the completions dump file). `zcomet` does all this and more. If you were to write a very careful `.zshrc` that did all of these things, it could potentially be very fast, but it would be long, complex, and hard to manage. In `zcomet`, it would be as simple as

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

*Copyright &copy; 2021 Alexandros Kozak*
