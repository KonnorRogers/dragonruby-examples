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
  # escape: "ESC",
  tab: "TAB",
  backspace: "BACKSPACE",
  space: "SPACE"
}

def key_to_string(key)
  SPECIAL_KEYS[key.to_sym] || KEY_HASH[key]&.fetch(:char, key.to_s)
end

def default_keybindings
  {
    "move_right" => key_to_string(:right_arrow),
    "move_left" => key_to_string(:left_arrow),
    "move_up" => key_to_string(:up_arrow),
    "move_down" => key_to_string(:down_arrow)
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

# Primitive for turning a value into a JSON string. Really dont feel like recursively looking through nested hashes and dealing with arrays. I'm lazy. Its not needed.
def to_json_value(value)
  return "null" if value.nil?

  return value.to_s if value.is_a?(Numeric)

  return "\"#{value.to_s.gsub('"', "'\"'")}\"" if value.is_a?(String) || value.is_a?(Symbol)

  raise "Value is not of type string, numeric, or nil"
end

# down and dirty to_json. No recursion. No Arrays. No hashes. (yet) just numbers, strings, and nil.
def to_json(hash, spacer = "  ", depth = 1)
  strs = []

  hash.each do |k, v|
    strs << "#{spacer * depth}\"#{k}\": #{to_json_value(v)}"
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

  text = "Keybindings will be saved to '#{args.state.keybindings_file}'"
  args.outputs.labels << { x: 640 - (text.length * 6), y: 30.from_top, text: text }

  if args.inputs.keyboard.s
    save_keybindings(args)
  end

  args.state.buttons = []

  args.state.keybinding_buttons = args.state.keybindings.map.with_index do |ary, index|
    key = ary[0]
    value = ary[1]

    hash = {}

    # This wont get used, but is useful for rebinding.
    hash[:method] = key

    hash[:id] = "#{key}_button".to_sym
    hash[:path] = "#{key}_button".to_sym
    hash[:text] = value
    hash[:action] = key
    hash[:h] = 50
    hash[:w] = 160
    hash[:x] = 640

    # multiple and subtract index to place them under each other
    hash[:y] = 200.from_top - index * 60

    args.state.buttons << hash

    # make sure to return the hash.
    hash
  end

  # Render buttons
  args.state.keybinding_buttons.each do |hash|
    args.outputs.labels << { x: hash[:x] - (hash[:w]), y: hash[:y] + ((hash[:h] * 2) / 3), h: hash[:h], text: "#{hash[:action]}" }
    create_button(args, id: hash[:id], text: hash[:text], w: hash[:w], h: hash[:h])
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

  # Render reset button
  create_button(args, id: reset_button[:id], text: reset_button[:text], w: reset_button[:w], h: reset_button[:h])

  # Push it to buttons.
  args.state.buttons << reset_button

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
    end
  end

  # render the buttons
  args.outputs.sprites << args.state.buttons

  track_keypresses(args)

  # if there was a selected button, print it's id
  if keybinding_button?(args, args.state.selected_button)
    text = "Set a keybinding for: #{args.state.selected_button[:method]}"
    args.outputs.labels << { x: 640 - (text.length * 6), y: 80.from_top, text: text }
  end

  if args.state.current_key && args.state.selected_button && args.state.current_key[:pressed_at] > args.state.selected_button[:selected_at]
    str = key_to_string(args.state.current_key[:key]).downcase

    set_keybinding(args, args.state.selected_button[:method], str) # will set `selected_button` to nil.
  end
end

def keybinding_button?(args, button)
  return false if button.nil?

  args.state.keybinding_buttons.find { |kb_button| kb_button[:id] == button[:id] }
end

def set_keybinding(args, method, str)
  # Dont do anything for empty methods.
  return if method.to_s.empty?

  # Make sure the keybinding exists.
  return if args.state.keybindings[method.to_s].nil?

  args.state.keybindings[method.to_s] = str
  save_keybindings(args)
  args.state.selected_button = nil
end

def create_button(args, id:, text:, w:, h:)
  # render_targets only need to be created once, we use the the id to determine if the texture
  # has already been created
  args.state.created_buttons ||= {}

  cached_button = args.state.created_buttons[id]
  return if cached_button && cached_button.text == text # this is an escape hatch to break the cache when the text changes.

  # if the render_target hasn't been created, then generate it and store it in the created_buttons cache
  args.state.created_buttons[id] = { created_at: Kernel.tick_count, id: id, w: w, h: h, text: text }

  # define the w/h of the texture
  args.outputs[id].w = w
  args.outputs[id].h = h

  # create a border
  args.outputs[id].borders << { x: 0, y: 0, w: w, h: h }

  # create a label centered vertically and horizontally within the texture
  args.outputs[id].labels << { x: w / 2, y: h / 2, text: text, vertical_alignment_enum: 1, alignment_enum: 1 }
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

$gtk.reset

