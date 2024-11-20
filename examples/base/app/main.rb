def tick(args)
  text = "Hello World"
  text_width, text_height = $gtk.calcstringbox(text)
  args.outputs.labels << { x: (1280 / 2) - (text_width / 2), y: (720 / 2) - (text_height / 2), text: text }
end

$gtk.reset

