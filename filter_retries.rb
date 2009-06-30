# #!/usr/local/bin/ruby
#                    
#filter_retry.rb
#Mark all records with value 7 in 6th column as QUERY_RETRY. Insert this step immediately after BOTS step. ...don’t include these searches in final valid searches.
require 'QClass.rb'
class Qry < QClass  
  def initialize( file_in, file_out, limit)
    super( file_in, file_out, limit)
    filter
  end

  def filter
    @retries = 0
  # READ LOOP
    File.open( file_in, modestring = "r") do |f|
      f.each($/) do |line|
        next if line =~ /^#/ or line =~ /^=/ or line =~ /^$/  #skip comment and blank lines
        limit?
        progress?
        fields = line.split("\t")
        fields[QRY_type] == QUERY_RETRY ? @retries += 1 : write(line)
      end #end of read block    
    end #end of file block

  wrap_up("\nRETRYs\t\t\t\t\t\t\t\t" + @retries.to_s  + "\n\n")
  end
end

Qry.new( (ARGV[0] ||= "qry_file.txt"), (ARGV[1] ||= "qry_file_out.txt"), (ARGV[2] ||= 100000000) )
