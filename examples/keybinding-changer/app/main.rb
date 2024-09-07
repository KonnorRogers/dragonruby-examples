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
KEY_TO_STRING = ::GTK::KeyboardKeys.method_to_key_hash

def load_keybindings(args)
  begin
    keybindings = {}
    # keybindings = $gtk.parse_json_file(args.state.keybindings_file)
  rescue StandardError
  end

  if keybindings.keys.length <= 0
    # Don't use symbols because $gtk.parse_json_file doesn't convert. So lets be consistent.
    keybindings = {
      "right" => "right_arrow",
      "left" => "left_arrow",
      "up" => "up_arrow",
      "down" => "down_arrow"
    }
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

def tick(args)
  args.gtk.disable_console
  args.state.keybindings_file ||= "keybindings.json"
  args.state.keybindings ||= load_keybindings(args)

  if args.inputs.keyboard.s
    save_keybindings(args)
  end


  idx = 0
  args.state.keybindings.map do |k, v|
    args.outputs.labels << { x: 500, y: 300.from_top - 30 * idx, text: "#{k}" }
    args.outputs.labels << { x: 600, y: 300.from_top - 30 * idx, text: "#{v}" }
    idx += 1
  end

  keyboard = args.inputs.keyboard

  # Special mapping for things you may want to render a different text label for.
  # For example: "escape" becomes "ESC"
  args.state.key_to_string ||= {
    escape: "ESC",
  }

  args.state.buttons ||= [
    # one button at the top
    { id: :up_button, text: "up_arrow", path: :up_button },
    { id: :down_button, text: "down_arrow", path: :down_button },
    { id: :left_button, text: "left_arrow", path: :left_button },
    { id: :right_button, text: "right_arrow", path: :right_button },
  ].map.with_index do |hash, index|
    hash[:h] = 50
    hash[:w] = 80
    hash[:x] = 640 - 250

    # multiple and subtract index to place them under each other
    hash[:y] = 80.from_top - index * 60

    # make sure to return the hash.
    hash
  end

  # check if a mouse click occurred
  if args.inputs.mouse.click
    # check to see if any of the buttons were intersected
    # and set the selected button if so
    args.state.selected_button = args.state.buttons.find { |b| b.intersect_rect? args.inputs.mouse }
  end

  args.state.buttons.each do |hash|
    create_button(args, hash[:id], hash[:text], hash[:w], hash[:h])
  end

  # render the buttons
  args.outputs.sprites << args.state.buttons

  args.state.down_or_held_keys ||= []
  args.state.modifier_keys ||= []
  down_or_held_keys = keyboard.keys[:down_or_held].reject { |k| IGNORED_KEYS.include?(k) || MODIFIER_KEYS.include?(k) }

  if down_or_held_keys.length > 0
    args.state.modifier_keys = []
    args.state.modifier_keys << :shift if keyboard.shift
    args.state.modifier_keys << :control if keyboard.control
    args.state.modifier_keys << :alt if keyboard.alt

    args.state.down_or_held_keys = down_or_held_keys
  end

  args.outputs.debug << "one: #{}"

  args.outputs.debug << "down keys: #{args.state.down_or_held_keys}"
  args.outputs.debug << "modifier keys: #{args.state.modifier_keys}"
  # args.outputs.debug << "#{args.state.pressed_key_chars}"

  # if there was a selected button, print it's id
  if args.state.selected_button
    args.outputs.labels << { x: 30, y: 30.from_top, text: "#{args.state.selected_button.id} was clicked." }
  end
end

def create_button(args, id, text, w, h)
  # render_targets only need to be created once, we use the the id to determine if the texture
  # has already been created
  args.state.created_buttons ||= {}
  return if args.state.created_buttons[id]

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


$gtk.reset
