# #!/usr/local/bin/ruby
#                    
#filter_count.rb
# Function -- count queries in file

require 'QClass.rb'
class Qry < QClass  
  def initialize( file_in, file_out, limit)
    super( file_in, file_out, limit)
    filter
  end
  
  def filter

    # READ LOOP
    File.open(file_in, modestring = "r") do |f|
      f.each($/) do |line|
        limit?
        #skip comments, empty lines
 #       write( @count.to_s + "\t" + line )
        progress?
        #read block
        end
      #file block    
      end
    #if verbose assume we want to see what's been going on
    wrap_up ""
  end
end

Qry.new( (ARGV[0] ||= "qry_file.txt"), "qry_file_out.txt", (ARGV[1] ||= 100000000) )
