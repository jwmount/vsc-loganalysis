# #!/usr/local/bin/ruby
#                    
#filter_count.rb
# Function -- count queries in file


require 'QClass.rb'
qry = QClass.new

qry.begin  
# READ LOOP
File.open(qry.qry_file, modestring = "r") do |f|
  f.each($/) do |line|
    qry.limit?
    qry.progress?
    qry.doit
  end  #end of read block    
end #end of file block
qry.wrap_up

