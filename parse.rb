
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end
  opts.on("-d", "--[no-]diagnostics", "Show diagnostics") do |d|
    options[:diagnostics] = d
  end
end.parse!

p options


