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

class Tile
  attr_sprite

  def initialize(
    x:,
    y:,
    w:,
    h:,
    path:
  )
    @x = x
    @y = y
    @w = w
    @h = h
    @path = path
  end
end


def tick(args)
  args.state.symbol_to_path ||= {
    plain: "sprites/1-bit-platformer/0108.png",
    rock: "sprites/rock-1.png",
    tree: "sprites/tree-1.png"
  }
  args.state.play_scene ||= PlayScene.new
  args.state.current_scene ||= args.state.play_scene
  current_scene = args.state.current_scene

  args.state.current_scene.tick(args)

  # make sure that the current_scene flag wasn't set mid tick
  if args.state.current_scene != current_scene
    raise "Scene was changed incorrectly. Set args.state.next_scene to change scenes."
  end

  # if next scene was set/requested, then transition the current scene to the next scene
  if args.state.next_scene
    # cleanup any state.
    args.state.current_scene.cleanup_state(args)

    # set current scene for next tick.
    args.state.current_scene = args.state.next_scene
    args.state.next_scene = nil
  end

  args.outputs.debug << "Framerate: #{$gtk.current_framerate}"
  # args.outputs.debug << "Player: #{state.player}"
  # args.outputs.debug << "Camera: #{state.camera}"
end

class PlayScene
  def tick(args)
    args.state.world ||= {
      height: 50_000,
      width: 50_000,
    }

    args.state.tile_size ||= 32
    args.state.tiles ||= generate_tiles(args)

    args.state.player ||= {
      x: 0,
      y: 0,
      w: 24,
      h: 24,
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
    args.outputs.background_color = [255, 255, 255]
    args.outputs[:scene].transient!
    args.outputs[:scene].w = Camera::VIEWPORT_SIZE
    args.outputs[:scene].h = Camera::VIEWPORT_SIZE

    args.state.tiles_to_render ||= []

    min_x = [state.camera.x - (Camera.scaled_screen_width(state.camera.scale) / 2) - (state.player.w / 2), 0].max
    min_y = [state.camera.y - (Camera.scaled_screen_height(state.camera.scale) / 2) - (state.player.h / 2), 0].max

    x_offset = (min_x / args.state.tile_size).floor
    y_offset = (min_y / args.state.tile_size).floor

    # How many extra tiles to render outside of the viewport.
    buffer_area = args.state.tile_size * 6

    max_x_tiles = ((Camera.scaled_screen_width(state.camera.scale)  + buffer_area) / args.state.tile_size).ceil
    max_y_tiles = ((Camera.scaled_screen_height(state.camera.scale) + buffer_area) / args.state.tile_size).ceil

    # if camera scale changes, remove extra tiles
    if max_x_tiles * max_y_tiles < args.state.tiles_to_render.length
      args.state.tiles_to_render.slice!(0, (max_x_tiles * max_y_tiles).ceil)
    end

    index = -1
    max_x_tiles.times do |x|
      max_y_tiles.times do |y|
        ary = args.state.tiles[x + x_offset]

        next if ary.nil? || ary.length <= 0

        tile = ary[y + y_offset]

        next if tile.nil?

        index += 1

        camera = args.state.camera
        tile_x = ((x + x_offset) * args.state.tile_size) * camera.scale - camera.x * camera.scale + Camera::VIEWPORT_SIZE_HALF
        tile_y = ((y + y_offset) * args.state.tile_size) * camera.scale - camera.y * camera.scale + Camera::VIEWPORT_SIZE_HALF
        tile_size = args.state.tile_size * camera.scale

        path = args.state.symbol_to_path[tile]

        # If the tile doesnt exist in rednered terrain, make it.
        args.state.tiles_to_render[index] ||= Tile.new(
          x: tile_x,
          y: tile_y,
          w: tile_size,
          h: tile_size,
          path: path
        )

        tile = args.state.tiles_to_render[index]

        tile.x = tile_x
        tile.y = tile_y
        tile.w = tile_size
        tile.h = tile_size
        tile.path = path
      end
    end

    args.outputs.debug << "camera_x: #{state.camera.x}"
    args.outputs.debug << "camera_y: #{state.camera.y}"
    args.outputs.debug << "min_x: #{min_x}"
    args.outputs.debug << "min_y: #{min_y}"
    args.outputs.debug << "Tiles on screen: #{args.state.tiles_to_render.length}"
    args.outputs.debug << "Total tiles: #{args.state.tiles.length * args.state.tiles[0].length}"

    args.outputs[:scene].sprites << [
      args.state.tiles_to_render,
      player_prefab(args)
    ]

    args.outputs.sprites << { **Camera.viewport, path: :scene }
  end

  def generate_tiles(args)
    tile_size = args.state.tile_size

    columns = ((args.state.world.width) / tile_size).round
    rows = ((args.state.world.height) / tile_size).round

    tiles = {}

    columns.times do |x|
      tiles[x] = {}
      rows.times do |y|
        random_num = rand * 100

        type = :plain

        # 1% chance to be a rock.
        if random_num > 99
          type = :rock
        end

        # 1% chance to be a tree.
        if random_num > 98 && random_num <= 99
          type = :tree
        end

        tiles[x][y] = type
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
    }

    camera = state.camera

    ease = 0.1
    state.camera.scale += (state.camera.target_scale - state.camera.scale) * ease

    state.camera.target_x = state.player.x
    state.camera.target_y = state.player.y

    # Makes sure we dont show empty space.
    min_x = [(Camera.scaled_screen_width(camera.scale) / 2) - (state.player.w / 2), state.camera.target_x].max
    min_y = [(Camera.scaled_screen_height(camera.scale) / 2) - (state.player.h / 2), state.camera.target_y].max
    state.camera.target_x = min_x
    state.camera.target_y = min_y

    state.camera.target_x = state.camera.target_x.clamp(state.camera.target_x, state.world.width - Camera.scaled_screen_width(camera.scale) / 2)
    state.camera.target_y = state.camera.target_y.clamp(state.camera.target_y, state.world.height - Camera.scaled_screen_height(camera.scale) / 2)

    state.camera.x += (state.camera.target_x - state.camera.x)
    state.camera.y += (state.camera.target_y - state.camera.y)
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
end


$gtk.reset

