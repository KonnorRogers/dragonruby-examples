GTK.ffi_misc.gtk_dlopen("ext")
include FFI::CExt
def tick(args)
  args.outputs.labels << {
    x: 640,
    y: 360,
    text: "Hello World"
  }
end
$gtk.reset

