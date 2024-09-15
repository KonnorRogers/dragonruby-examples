def tick(args)
  # press i to run benchmark using iterations
  if args.inputs.keyboard.key_down.i
    args.gtk.console.show
    args.gtk.benchmark iterations: 1000, # number of iterations
                       # label for experiment
                       using_numeric_map: -> () {
                         # experiment body
                         v = 100.map_with_index do |i|
                           i * 100
                         end
                       },
                       # label for experiment
                       using_numeric_times: -> () {
                         # experiment body
                         v = []
                         100.times do |i|
                           v << i * 100
                         end
                       }
  end
end

$gtk.reset
