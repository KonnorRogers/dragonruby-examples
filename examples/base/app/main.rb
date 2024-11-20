def tick(args)
  text = "Hello World"
  args.outputs.labels << { x: (1280 / 2), y: (720 / 2), anchor_x: 0.5, anchor_y: 0.5, text: text }
end

$gtk.reset

