PALETTE = {
  black: { r: 0, b: 0, g: 0, a: 255 },
  white: { r: 255, b: 255, g: 255, a: 255 },
  red: { r: 255, g: 0, b: 0, a: 255 },
  blue: { r: 0, g: 0, b: 255, a: 255 },
  danger: {
    "900": { r: 255, b: 0, g: 0, a: 255 }
  },
  alphas: {
    solid: { a: 255 },
    semi_transparent: { a: 128 },
    mostly_transparent: { a: 64 },
    transparent: { a: 0 },
  }
}
def tick(args)
  box = {
    x: 100,
    y: 0,
    w: 50,
    h: 50,
    path: :pixel
  }
  red_box = box.merge({
    **PALETTE.red,
  })
  blue_box = box.merge({
    y: 125,
    **PALETTE.blue
  })

  mostly_transparent_blue_box = box.merge({
    y: 250,
    **PALETTE.blue,
    **PALETTE.alphas.mostly_transparent
  })

  light_blue_box = box.merge({
    y: 375,
    **PALETTE.blue
  })
  light_blue_box_filter = light_blue_box.merge({
    **PALETTE.white,
    **PALETTE.alphas.mostly_transparent
  })

  dark_blue_box = box.merge({
    y: 500,
    **PALETTE.blue
  })
  dark_blue_box_filter = dark_blue_box.merge({
    **PALETTE.black,
    **PALETTE.alphas.mostly_transparent
  })
  args.outputs.sprites << [
    red_box, blue_box, mostly_transparent_blue_box,
    light_blue_box, light_blue_box_filter,
    dark_blue_box_filter, dark_blue_box,
  ]
end
$gtk.reset
