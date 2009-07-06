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
    @dtcount = Array.new(31,0).map!{Array.new(24,0)}

    # READ LOOP
    File.open( file_in, modestring = "r") do |f|
      f.each($/) do |line|
        next if line =~ /^#|^=/  or line =~ /^$/  #skip comment and blank lines
        limit?
        progress?
        fields = line.split("\t")
        dt = fields[0]
        @d = dt[-11,2].to_i
        @t = dt[-8,2].to_i
        unless @dtcount[@d][@t].nil?
          @n = @dtcount[@d][@t]
          @n += 1
          @dtcount[@d][@t] = @n
        else
          @dtcount[@d][@t] = 1
        end
      end #read block    
  end #file block

  # HOURLY DISTRIBUTION
  log( "Hourly frequency distribution by day of month\n_____________________________________________\n\n" )
  log ""
  i = 0
  # each element in @dtcount is an array of hours so we iterate over @dtcount itself, NOT @dtcount[1..31].each do |d|
  @dtcount.each do |d|
    i += 1
    log "Day\tmidnight" + "\t" * 3 + "04 am" + "\t" * 4 + "08 am" + "\t"* 4 + "noon"+ "\t"*4 + "04 pm" + "\t"*4 + "08 pm\n" if i == 1
    log i.to_s + "\t" 
    d[0..23].each {|x| log x.to_s + "\t"}
    log "\n"
  end

  
  wrap_up("\n" )
  end
end

Qry.new( (ARGV[0] ||= "qry_file.txt"), (ARGV[1] ||= "qry_file_out.txt"), (ARGV[2] ||= 100000000) )
