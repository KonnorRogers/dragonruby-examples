#include <dragonruby.h>
#include <emscripten.h>

/// https://github.com/DragonRuby/dragonruby-game-toolkit-contrib/tree/df9e3bb7f2fc873eceac9bec77389bc36a0d7280/samples/12_c_extensions

/// This one is accessible from Ruby as `run_js_script`
/// Very simple wrapper around emscripten exposing "run_script" to ruby.
/// https://emscripten.org/docs/api_reference/emscripten.h.html#c.emscripten_run_script
DRB_FFI
void run_js_script(const char *script) {
  emscripten_run_script(*script)
}

/// Compile the bindings like so:

/*
dragonruby-bind bridge.c --output=bindings.c
# DRB_ROOT is the path to the gtk source directory
clang -shared \
  -isystem $DRB_ROOT/mruby/include/ \
  -isystem $DRB_ROOT/ \
  -o mygame/native/emscripten-wasm/bindings.dylib \
  bindings.c
*/

