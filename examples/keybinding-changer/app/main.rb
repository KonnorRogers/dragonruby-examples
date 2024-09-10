# These keys dont really map to anything.
IGNORED_KEYS = [:char, :raw_key]

# We dont really expect modifier keys to be used as actual keys.
MODIFIER_KEYS = [
  :control,
  :control_left,
  :control_right,

  :shift,
  :shift_right,
  :shift_left,

  :meta,
  :meta_left,
  :meta_right,

  :alt,
  :alt_left,
  :alt_right,
]

# Use this to convert symbols like :one to "1"
KEY_HASH = ::GTK::KeyboardKeys.method_to_key_hash

# Special mapping for things you may want to render a different text label for.
# For example: "escape" becomes "ESC"
SPECIAL_KEYS = {
  escape: "ESC",
  tab: "TAB",
  backspace: "BACKSPACE",
  space: "SPACE"
}

# Transform a given key ie: `:space` into "SPACE"
def key_to_string(key)
  SPECIAL_KEYS[key.to_sym] || KEY_HASH[key]&.fetch(:char, key.to_s)
end

def create_button(args, id:, text:, w:, h:, hover: false, **kwargs)
  # render_targets only need to be created once, we use the the id to determine if the texture
  # has already been created
  args.state.created_buttons ||= {}

  cached_button = args.state.created_buttons[id]

  # Cache checks if we need to make a new render.
  return if cached_button && cached_button.text == text && cached_button.hover == hover

  # if the render_target hasn't been created, then generate it and store it in the created_buttons cache
  args.state.created_buttons[id] = { created_at: Kernel.tick_count, id: id, w: w, h: h, text: text }

  # Make it transient or dragonruby yells at your about performance issues.
  args.outputs[id].transient!
  # define the w/h of the texture
  args.outputs[id].w = w
  args.outputs[id].h = h

  # create a border
  args.outputs[id].borders << { x: 0, y: 0, w: w, h: h }

  # Render gray background when hovered.
  bg_color = hover ? {r: 200, g: 200, b: 200, a: 255 } : { r: 0, g: 0, b: 0, a: 0 }

  args.outputs[id].solids << { x: 0, y: 0, w: w, h: h, **bg_color }
  # create a label centered vertically and horizontally within the texture
  args.outputs[id].labels << { x: w / 2, y: h / 2, text: text, vertical_alignment_enum: 1, alignment_enum: 1 }
end


def default_keybindings
  {
    "move_right" => {
      "display_key" => key_to_string(:right_arrow),
      "keyboard_key" => "right_arrow" # "keyboard_key" is what will get transformed into a symbol and passed to args.state.keyboard.
    },
    "move_left" => {
      "display_key" => key_to_string(:left_arrow),
      "keyboard_key" => "left_arrow"
    },
    "move_up" => {
      "display_key" => key_to_string(:up_arrow),
      "keyboard_key" => "up_arrow"
    },
    "move_down" => {
      "display_key" => key_to_string(:down_arrow),
      "keyboard_key" => "down_arrow"
    },
  }
end

def load_keybindings(args)
  begin
    keybindings = $gtk.parse_json_file(args.state.keybindings_file)
  rescue StandardError
  end

  if keybindings.keys.length <= 0
    # Don't use symbols because $gtk.parse_json_file doesn't convert. So lets be consistent.
    keybindings = default_keybindings
  end

  keybindings
end

# Primitive for turning a value into a JSON string. Right now it supports Hash, Numeric, String, Symbol, and nil. Didnt add support for arrays because it wasn't needed. But if you plan to do key combos...it could be helpful?
def to_json_value(value, spacer, depth)
  return "null" if value.nil?

  return value.to_s if value.is_a?(Numeric)

  return "\"#{value.to_s.gsub('"', "'\"'")}\"" if value.is_a?(String) || value.is_a?(Symbol)

  if value.is_a?(Hash)
    inner_depth = depth + 1
    strings = value.map do |k, v|
      "#{spacer * inner_depth}" + to_json_value(k, spacer, inner_depth) + ": " + to_json_value(v, spacer, inner_depth)
    end.join(",\n")

    leading_space = "#{spacer * depth}"
    return "{\n" + strings + "\n#{leading_space}}"
  end

  raise "Value is not of type String, Symbol, Hash, Numeric, or nil"
end

# down and dirty to_json. No Arrays. just hashes, numbers, symbols, strings, and nil.
def to_json(hash, spacer = "  ", depth = 1)
  strs = []

  hash.each do |k, v|
    strs << "#{spacer * depth}\"#{k}\": #{to_json_value(v, spacer, depth)}"
  end

  "{\n" + strs.join(",\n") + "\n}"
end

def save_keybindings(args)
  $gtk.write_file(args.state.keybindings_file, to_json(args.state.keybindings))
end

def reset_keybindings(args)
  # no need to do extra work if we already reset.
  return if args.state.keybindings == args.state.default_keybindings

  args.state.keybindings = default_keybindings
  save_keybindings(args)
end

def tick(args)
  args.gtk.disable_console
  args.state.keybindings_file ||= "keybindings.json"
  args.state.keybindings ||= load_keybindings(args)

  args.state.keybindings_scene ||= KeybindingScene.new
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
end

# This is a very minimal game where we make use of the keybindings we set.
class PlayScene
  def tick(args)
    args.state.player ||= {
      x: 640,
      y: 360,
      h: 32,
      w: 32,
      r: 0,
      g: 0,
      b: 255,
      speed: 5,
    }

    # Here's where we make use of keybindings by "abusing" send.
    move_left = args.inputs.keyboard.send(args.state.keybindings["move_left"]["keyboard_key"])
    move_right = args.inputs.keyboard.send(args.state.keybindings["move_right"]["keyboard_key"])
    move_up = args.inputs.keyboard.send(args.state.keybindings["move_up"]["keyboard_key"])
    move_down = args.inputs.keyboard.send(args.state.keybindings["move_down"]["keyboard_key"])

    args.state.player.x -= 5 if move_left
    args.state.player.x += 5 if move_right
    args.state.player.y += 5 if move_up
    args.state.player.y -= 5 if move_down

    args.state.player.x = args.state.player.x.clamp(0, args.grid.w)
    args.state.player.y = args.state.player.y.clamp(0, args.grid.h)

    args.state.keybinding_button ||= {
      id: "show_keybindings_button",
      path: "show_keybindings_button",
      x: 300.from_right,
      y: 80.from_top,
      # anchor_y: 0.5,
      # anchor_x: 0.5,
      w: 200,
      h: 50,
      text: "Change keybindings",
    }

    args.state.buttons = []
    create_button(args, **args.state.keybinding_button)
    args.state.buttons << args.state.keybinding_button

    # Hover checking
    if args.inputs.mouse
      args.state.buttons.each do |b|
        b[:hover] = b.intersect_rect?(args.inputs.mouse)
      end
    end

    # Check for click to other scene
    if args.inputs.mouse.click && args.state.keybinding_button.intersect_rect?(args.inputs.mouse)
      args.state.next_scene = args.state.keybindings_scene
    end

    args.outputs.sprites << [args.state.buttons, args.state.player]

    args.state.keybinding_labels ||= args.state.keybindings.map.with_index do |ary, index|
      method = ary[0]
      hash = ary[1]
      [
        # thing to do
        {
          x: 250.from_right,
          y: 300.from_top + index * 60,
          w: 300,
          anchor_x: 0.5,
          anchor_y: 0.5,
          text: method + ": ",
        },

        # key to press
        {
          x: 100.from_right,
          y: 300.from_top + index * 60,
          w: 300,
          anchor_x: 0.5,
          anchor_y: 0.5,
          text: hash["display_key"],
        }
      ]
    end
    args.outputs.labels << args.state.keybinding_labels
  end

  def cleanup_state(args)
    args.state.buttons = []
    args.state.keybinding_labels = nil
  end
end

# This is where keybinding remapping happens.
class KeybindingScene
  # I know i could use attr_gtk here, but I prefer to keep it closer to a simple tick function.


  def tick(args)
    text = "Keybindings will be saved to '#{args.state.keybindings_file}'"
    args.outputs.labels << { x: 640, anchor_x: 0.5, anchor_y: 0.5, y: 30.from_top, text: text }

    args.state.buttons = []

    # Create buttons in state, but don't render yet. We need to do hover checking before we render.
    create_buttons(args)

    # check if a mouse click occurred
    if args.inputs.mouse.click
      # check to see if any of the buttons were intersected
      # and set the selected button if so
      args.state.selected_button = args.state.buttons.find { |b| b.intersect_rect? args.inputs.mouse }

      if args.state.selected_button
        args.state.selected_button[:selected_at] = Kernel.tick_count

        if args.state.selected_button[:id] == "reset_keybindings_button"
          reset_keybindings(args)
        end

        if args.state.selected_button[:id] == "play_button"
          args.state.next_scene = args.state.play_scene
        end
      end
    end

    # render the buttons
    args.outputs.sprites << args.state.buttons

    track_keypresses(args)

    # if there was a selected button, print it's id
    if keybinding_button?(args, args.state.selected_button)
      text = "Set a keybinding for: #{args.state.selected_button[:action]}"
      args.outputs.labels << { x: 640, anchor_x: 0.5, anchor_y: 0.5, y: 80.from_top, text: text }
    end

    if args.state.current_key && args.state.selected_button && args.state.current_key[:pressed_at] > args.state.selected_button[:selected_at]


      keyboard_key = args.state.current_key[:key]
      display_key = key_to_string(keyboard_key).downcase

      set_keybinding(args, args.state.selected_button[:action], keyboard_key, display_key) # will set `selected_button` to nil.
    end
  end

  def cleanup_state(args)
    # Cleanup before we render next scene.
    # Notice we DO NOT clean up "args.state.keybindings" so we can use them in the game.
    args.state.buttons = []
    args.state.selected_button = nil
    args.state.current_key = nil
    args.state.down_keys = nil
    args.state.modifier_keys = nil
    args.state.current_key = nil
    args.state.reset_button = nil
    args.state.play_button = nil
  end


  # Stores the buttons as a hash in state
  def create_buttons(args)
    args.state.keybinding_buttons = args.state.keybindings.map.with_index do |ary, index|
      key = ary[0]
      value = ary[1]

      display_key = value["display_key"]
      keyboard_key = value["keyboard_key"]

      hash = {}

      # This wont get used, but is useful for tracking the "action" IE: "move_left"
      hash[:action] = key

      hash[:id] = "#{key}_button".to_sym
      hash[:path] = "#{key}_button".to_sym
      hash[:text] = display_key

      # keyboard_key is what is args.inputs.keyboard.<keyboard_key>
      hash[:keyboard_key] = keyboard_key
      hash[:h] = 50
      hash[:w] = 160
      hash[:x] = 640

      # multiple and subtract index to place them under each other
      hash[:y] = 200.from_top - index * 60

      args.state.buttons << hash

      # make sure to return the hash.
      hash
    end

    last_button = args.state.buttons[-1]
    args.state.reset_button ||= {
      id: "reset_keybindings_button",
      path: "reset_keybindings_button",
      text: "Reset keybindings",
      x: last_button[:x] - last_button[:w],
      y: last_button[:y] - 100,
      w: 325,
      h: 50
    }
    reset_button = args.state.reset_button

    args.state.play_button ||= {
      id: "play_button",
      path: "play_button",
      text: "Play Game",
      x: reset_button[:x],
      y: reset_button[:y] - 100,
      w: 325,
      h: 50
    }
    play_button = args.state.play_button

    # Push it to buttons.
    args.state.buttons << reset_button
    args.state.buttons << play_button

    # Hover checking
    if args.inputs.mouse
      args.state.buttons.each do |b|
        b[:hover] = b.intersect_rect?(args.inputs.mouse)
      end
    end

    # Render reset button
    create_button(args, **reset_button)

    # Render play button
    create_button(args, **play_button)

    # Render keybinding buttons
    args.state.keybinding_buttons.each do |hash|
      args.outputs.labels << { x: hash[:x] - 75, anchor_x: 0.5, anchor_y: 0.6, y: hash[:y] + (hash[:h] / 2), h: hash[:h], text: "#{hash[:action]}" }
      create_button(args, **hash)
    end
  end

  def keybinding_button?(args, button)
    return false if button.nil?

    args.state.keybinding_buttons.find { |kb_button| kb_button[:id] == button[:id] }
  end

  def set_keybinding(args, method, keyboard_key, display_key)
    # Dont do anything for empty methods.
    return if method.to_s.empty?

    # Make sure the keybinding exists.
    return if args.state.keybindings[method.to_s].nil?

    already_set_method = args.state.keybindings.find do |ary|
      key = ary[0]
      # We dont care if they set it to the same keybinding.
      next if key == method

      value = ary[1]["display_key"]
      value == display_key
    end

    if already_set_method
      error_message = "\"#{display_key}\" is already set for \"#{already_set_method[0]}\"."
      args.outputs.labels << { x: 640, anchor_x: 0.5, anchor_y: 0.5, y: 120.from_top, text: error_message, r: 255, b: 0, g: 0}
      return
    end

    args.state.keybindings[method.to_s] = {
      "display_key" => display_key,
      "keyboard_key" => keyboard_key,
    }
    save_keybindings(args)
    args.state.selected_button = nil
  end

  def track_keypresses(args)
    args.state.down_keys ||= []
    args.state.modifier_keys ||= []
    args.state.current_key ||= nil

    keyboard = args.inputs.keyboard

    # The key you want will always be the last key. For example Shift+1 which will end up as `[:one, :exclamation_point]`.
    down_keys = keyboard.keys[:down]
      .reject { |k| IGNORED_KEYS.include?(k) || MODIFIER_KEYS.include?(k) }
      # Remove "_scancode", to my knowledge its unnecessary. things like `:s_scancode`
      .map { |k| k.to_s.gsub("_scancode", "").to_sym }
      .uniq

    if down_keys.length > 0
      args.state.modifier_keys = []
      args.state.modifier_keys << :shift if keyboard.shift
      args.state.modifier_keys << :control if keyboard.control
      args.state.modifier_keys << :alt if keyboard.alt
      args.state.modifier_keys << :meta if keyboard.meta

      args.state.down_keys = down_keys

      current_key = down_keys[0]

      # Check to make sure its not a "shifted" key. We iterate through all the down keys, and check to see if they exist in the "shift_char_hash"
      if keyboard.shift
        down_keys.each do |k|
          shifted_key = ::GTK::KeyboardKeys.char_to_shift_char_hash[k]
          if shifted_key
            current_key = shifted_key
          end
        end
      end

      # Takes the last key in the array.
      args.state.current_key = {
        key: current_key,
        pressed_at: Kernel.tick_count
      }

      args.state.debug_current_key = current_key
    end

    args.outputs.debug << "down keys: #{args.state.down_keys}"
    args.outputs.debug << "modifier keys: #{args.state.modifier_keys}"

    if args.state.current_key
      args.outputs.debug << "current key: #{key_to_string(args.state.debug_current_key)}"
    end
  end
end

$gtk.reset

