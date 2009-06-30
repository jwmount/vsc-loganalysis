# #!/usr/local/bin/ruby
#                    
#filter_valids.rb
#Query is valid if { YB_api_errors is not present or value is '0'

require 'QClass.rb'
class Qry < QClass  
  def initialize( file_in, file_out, limit)
    super( file_in, file_out, limit)
    filter
  end

  def filter
    @valids = 0
    @local_lines_out = 0
  # READ LOOP
    File.open( file_in, modestring = "r") do |f|
      f.each($/) do |line|
        next if line =~ /^#/ or line =~ /^=/ or line =~ /^$/  #skip comment and blank lines
        limit?
        progress?
        fields = line.split("\t")
    #TESTING
        if(fields.length == QUERY_FIELDS)
          @local_lines_out += 1
          write( @local_lines_out.to_s + "\t" + line)
        end
    #END TESTING
        if(fields.length < QUERY_FIELDS) 
          write(line)
          @valids += 1
          next 
        end
        if fields[QUERY_VALID] == '0'
          write(line)
          @valids += 1
        end
      end #end of read block    
    end #end of file block
  wrap_up("\nVALID queries\t\t\t\t\t\t" + @valids.to_s  + "\n\n")
  end
end

Qry.new( (ARGV[0] ||= "qry_file.txt"), (ARGV[1] ||= "qry_file_out.txt"), (ARGV[2] ||= 100000000) )
