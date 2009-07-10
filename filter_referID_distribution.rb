# #!/usr/local/bin/ruby
#                    
require 'QClass.rb'
# Bot list from Intelius, downcased for case insensitivity

class Qry < QClass  
  def initialize( file_in, out_file, limit)
    super( file_in, out_file, limit)
    filter
  end

  def filter    
    @refID_hash = {}
        
    # READ LOOP
    File.open( file_in, modestring = "r") do |f|
      f.each($/) do |line|
      next if line =~ /^#|^=/  or line =~ /^$/  #skip comment and blank lines
      limit?
      progress?
      fields = line.split("\t")
      if !@refID_hash.has_key?(fields[R_ID])    #if not in hash yet, add it
         @refID_hash.update(fields[R_ID]=>1)
      else                                      #if is, increment value and next record
        @refID_hash[ fields[R_ID] ] = @refID_hash.fetch( fields[R_ID] ) + 1
      end
    end #read block    
  end #file block

  # REFERER ID FREQUENCY DISTRIBUTION
  log( "\nFrequency distribution by referID\n___________________________________\n\n" )
  log( "referer ID\t\tcount\n\n")
  @refID_hash.sort{|a,b| b[1]<=>a[1]}.each do |key, value|
    @total = ( @total ||= 0 ) + value
    log( "  " + key.to_s + "\t\t\t" + value.to_s + "\n")
    end
  log "\n  total\t\t\t" + @total.to_s  

  wrap_up("\n" )

  end
end

Qry.new( (ARGV[0] ||= "qry_file.txt"), (ARGV[1] ||= "qry_file_out.txt"), (ARGV[2] ||= 100000000) )
