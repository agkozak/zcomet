# Fixture: a plugin that follows the Zsh Plugin Standard unload protocol by
# defining <name>_plugin_unload. Used to test `zcomet unload` (SUGGESTIONS 1.4).
typeset -g UNLOAD_DEF=1

unloadable_plugin_unload() {
  typeset -g UNLOAD_RAN=1
}
