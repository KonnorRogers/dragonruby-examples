class Camera
  SCREEN_WIDTH = 1280
  SCREEN_HEIGHT = 720

  VIEWPORT_SIZE = 1500
  VIEWPORT_SIZE_HALF = VIEWPORT_SIZE / 2

  OFFSET_X = (SCREEN_WIDTH - VIEWPORT_SIZE) / 2
  OFFSET_Y = (SCREEN_HEIGHT - VIEWPORT_SIZE) / 2

  class << self
    def to_world_space camera, rect
      x = (rect.x - VIEWPORT_SIZE_HALF + camera.x * camera.scale - OFFSET_X) / camera.scale
      y = (rect.y - VIEWPORT_SIZE_HALF + camera.y * camera.scale - OFFSET_Y) / camera.scale
      w = rect.w / camera.scale
      h = rect.h / camera.scale
      rect.merge x: x, y: y, w: w, h: h
    end

    def to_screen_space camera, rect
      x = rect.x * camera.scale - camera.x * camera.scale + VIEWPORT_SIZE_HALF
      y = rect.y * camera.scale - camera.y * camera.scale + VIEWPORT_SIZE_HALF
      w = rect.w * camera.scale
      h = rect.h * camera.scale
      rect.merge x: x, y: y, w: w, h: h
    end

    def viewport
      {
        x: OFFSET_X,
        y: OFFSET_Y,
        w: 1500,
        h: 1500
      }
    end

    def viewport_world camera
      to_world_space camera, viewport
    end

    def find_all_intersect_viewport camera, os
      Geometry.find_all_intersect_rect viewport_world(camera), os
    end

    def scaled_screen_height scale
      SCREEN_HEIGHT / scale
    end

    def scaled_screen_width scale
      SCREEN_WIDTH / scale
    end
  end
end

def generate_tiles(args)
  tile_size = args.state.tile_size

  columns = ((args.state.world.width) / tile_size).round
  rows = ((args.state.world.height) / tile_size).round

  tiles = []

  columns.times do |x|
    tiles[x] = []
    rows.times do |y|
      tiles[x][y] = {
        x: x * tile_size,
        y: y * tile_size,
        w: tile_size,
        h: tile_size,
        path: "sprites/1-bit-platformer/0108.png",
      }
    end
  end

  tiles
end


def calc_camera(args)
  state = args.state
  state.camera ||= {
    x: 0,
    y: 0,
    target_x: 0,
    target_y: 0,
    target_scale: 2,
    scale: 1,
    show_empty_space: false,
  }

  camera = state.camera

  ease = 0.1
  state.camera.scale += (state.camera.target_scale - state.camera.scale) * ease

  state.camera.target_x = state.player.x
  state.camera.target_y = state.player.y

  if !state.camera.show_empty_space
    min_x = [(Camera.scaled_screen_width(camera.scale) / 2) - (state.player.w / 2), state.camera.target_x].max
    min_y = [(Camera.scaled_screen_height(camera.scale) / 2) - (state.player.h / 2), state.camera.target_y].max
    state.camera.target_x = min_x
    state.camera.target_y = min_y

    state.camera.target_x = state.camera.target_x.clamp(state.camera.target_x, state.world.width - Camera.scaled_screen_width(camera.scale) / 2)
    state.camera.target_y = state.camera.target_y.clamp(state.camera.target_y, state.world.height - Camera.scaled_screen_height(camera.scale) / 2)
  end

  state.camera.x += (state.camera.target_x - state.camera.x)
  state.camera.y += (state.camera.target_y - state.camera.y)

  state.camera.show_empty_space = !state.camera.show_empty_space if args.inputs.keyboard.key_down.tab
end

def calc_movement(args)
  player = args.state.player
  player.x += player.dx
  player.y += player.dy

  player.dx *= 0.8
  if player.dx.abs < 0.1
    player.dx = 0
  end

  player.dy *= 0.8
  if player.dy.abs < 0.1
    player.dy = 0
  end

  player.x = player.x.clamp(0, args.state.world.width - ((player.w * 3) / 2))
  player.y = player.y.clamp(0, args.state.world.height - ((player.h * 3) / 2))
end

def player_prefab(args)
  path = "sprites/1-bit-platformer/0280.png"

  prefab = Camera.to_screen_space args.state.camera, (args.state.player.merge path: path)

  frame_index = 0.frame_index 3, 5, true

  if args.state.player.direction == "right"
    prefab.merge! path: "sprites/1-bit-platformer/028#{frame_index + 1}.png"
  elsif args.state.player.direction == "left"
    prefab.merge! path: "sprites/1-bit-platformer/028#{frame_index + 1}.png", flip_horizontally: true
  end

  prefab
end

def tick(args)
  args.state.world ||= {
    height: 5000,
    width: 5000,
  }

  args.state.tile_size ||= 32
  args.state.tiles ||= generate_tiles(args)

  args.state.player ||= {
    x: 0,
    y: 0,
    w: 16,
    h: 16,
    dy: 0,
    dx: 0,
    direction: "right",
    path: "sprites/1-bit-platformer/0280.png"
  }

  state = args.state
  player = state.player

  if args.inputs.directional_angle
    dx = args.inputs.directional_angle.vector_x * 1.4
    dy = args.inputs.directional_angle.vector_y * 1.4

    # vector_* comes out to like 0.00000003 or some floating point bullshit above 0. This accounts for that.
    dx.abs < 1 ? player.dx = 0 : player.dx = dx
    dy.abs < 1 ? player.dy = 0 : player.dy = dy

    # args.outputs.debug << "dx: #{dx}, dy: #{dy}"

    player.dx += dx
    player.dy += dy

    # make sure the person is actually moving right / left.
    if dy.abs < 1
      if player.dx > 0
        player.direction = "right"
      elsif player.dx < 0
        player.direction = "left"
      end
    end
  end

  if args.inputs.keyboard.key_down.equal_sign || args.inputs.keyboard.key_down.plus
    state.camera.target_scale += 0.25
  elsif args.inputs.keyboard.key_down.minus
    state.camera.target_scale -= 0.25
    state.camera.target_scale = 0.25 if state.camera.target_scale < 0.25
  elsif args.inputs.keyboard.zero
    state.camera.target_scale = 1
  end

  calc_camera(args)
  calc_movement(args)
  args.outputs[:scene].transient!
  args.outputs[:scene].w = Camera::VIEWPORT_SIZE
  args.outputs[:scene].h = Camera::VIEWPORT_SIZE

  terrain_to_render = Camera.find_all_intersect_viewport(state.camera, state.tiles.flatten)

  args.outputs[:scene].sprites << terrain_to_render.map do |m|
    Camera.to_screen_space(state.camera, m)
  end

  args.outputs[:scene].sprites << [player_prefab(args)]


  args.outputs.sprites << { **Camera.viewport, path: :scene }

    args.outputs[:scene].sprites << {
      x: 135,                         # position
      y: 980,
      w: Camera::SCREEN_WIDTH / 3,                         # size
      h: 150,
      r: 0,                         # color saturation
      g:  0,
      b:  0,
      a: 200                          # transparency
    }

  # create a label centered vertically and horizontally within the texture
  args.outputs[:scene].labels << {
                      x: 350,
                      y: 1085,
                      anchor_x: 0.5,
                      text: "Arrow Keys / WASD: move around.",
                      r: 255,
                      g: 255,
                      b: 255 }

  args.outputs[:scene].labels << {
                      x: 350,
                      y: 1055,
                      anchor_x: 0.5,
                      text: "+/- to change zoom",
                      r: 255,
                      g: 255,
                      b: 255 }

  args.outputs[:scene].labels << {
                      x: 350,
                      y: 1025,
                      anchor_x: 0.5,
                      text: "Tab to change showing empty space",
                      r: 255,
                      g: 255,
                      b: 255 }



  # args.outputs.debug << "Framerate: #{$gtk.current_framerate}"
  # args.outputs.debug << "Player: #{state.player}"
  # args.outputs.debug << "Camera: #{state.camera}"
end


$gtk.reset
