PALETTE = {
  red: { r: 255, g: 0, b: 0, a: 255 },
  blue: { r: 0, g: 0, b: 255, a: 255 },
}
def tick(args)
  box = {
    w: 50,
    h: 50,
    path: :pixel
  }
  red_box = box.merge({
    x: 100,
    y: 100,
    **PALETTE.red,
  })
  blue_box = box.merge({
    x: 200,
    y: 200,
    **PALETTE.blue
  })
  args.outputs.sprites << [red_box, blue_box]
end
$gtk.reset

