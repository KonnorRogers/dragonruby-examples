# will find mygame/native/emscripten-wasm/bindings.c that you compiled with `clang`
$gtk.ffi_misc.dlopen("bindings")

def tick args
  if Kernel.tick_count <= 0
    FFI::CExt::("console.log('Hello World')")
  end
end
GTK.reset
