def tick(args)
  # Create the render target only on the first tick. Its then cached and used indefinitely.
  if Kernel.tick_count <= 0
    args.outputs[:black_box].w = 100
    args.outputs[:black_box].h = 100
    args.outputs[:black_box].background_color = [0,0,0,0] # r: 0, b: 0, g: 0, a: 64 (alpha)
    args.outputs[:black_box].sprites << {x: 0, y: 0, w: 100, h: 100, r: 0, b: 0, g: 0, a: 64, path: :pixel}
    # args.outputs[:black_box].clear_before_render = false # r: 0, b: 0, g: 0, a: 64 (alpha)
  end

  # Turn the cached render target into a "sprite"
  # render_target = args.outputs[:black_box] # dont do this, itll clear the render target's cache.
  render_target_sprite = {
    x: 100,
    y: 100,
    w: 100,
    h: 100,
    path: :black_box,
  }

  # Create an angled version and overlay it.
  angled_render_target = render_target_sprite.merge({
    angle: 45,
    angle_anchor_x: 0.5,
    angle_anchor_y: 0.5
  })

  # Scale it up 2x and render it!
  scaled_render_target = render_target_sprite.merge({
    x: 400,
    y: 400,
    w: 200,
    h: 200,
  })

  # Render the render targets
  args.outputs.sprites << [
    render_target_sprite,
    angled_render_target,
    scaled_render_target
  ]
end

$gtk.reset
