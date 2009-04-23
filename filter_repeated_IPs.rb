# #!/usr/local/bin/ruby
#                    
#filter_repeated_IPs.rb
# Function -- filter bots out of Intelius log
# Filter Sequence to run (all file types are .txt)
#
# script                   default in          default out          discussion                                                       status determined
# ______________           ______________      _________________    _____________________________________________________________    _________________
# filter_extract           qry_file_in         qry_file_out         reads any qry file, removes/writes matches on MATCH_ON string    STATUS_COUNT
# filter_unique_domains    qry_file_in         none                 reads any qry file, logs frequency distribution unique domains   STATUS_COUNT
# filter_bots              qry_file_out        qry_file_bots_out    reads any qry file, bots counted and removed from output         STATUS_BOTS
# filter_inUS              qry_file_bots_out   qry_file_isUS_out    reads raw or filtered, removes locations not in US               STATUS_NOWHERE
# filter_repeated_IPs      qry_file_isUS_out   qry_file_notRep_out  reads raw or filtered, removes repetitive incoming IPs           STATUS_REPEATS
# filter_count             qry_file_notRep_out none                 reads any qry file, EXTRACT_ON = nil (just count)                STATUS_OK                              

# QRY_FILE format
# 0  $date time – date and time of request with em bedded space
# 1  $site – This is our internal site id. We have dozens of sites that use yellowbook API.   Ignore
# 2  $referId – This is our internal lead tracking number.                                    Ignore
# 3  $provider – This is always 107 (yellowbook API)                                          Ignore
# 4  $searchType – This will have values between 11 and 14.                                   Ignore
# 5  $queryType – This field can have one of these values: -1 (API returned an error), 1(multi results page), 2(no results found), 3(details or more info page), 4 (next page using pagination), 5(this search is same as previous search – search is repeated), 11 (search resulted in category listings). I can give more details on this if you need.
# 6  $clientIp – client IP addresses
# 7  $isBot – We consider this request is from a bot. This is according to our definition. Your definition might be different.  Ignore
# 8  $_SERVER['HTTP_HOST'] – requested domain name.                                           Ignore
# 9  $_SERVER['REQUEST_URI'] – requested URI.                                                 Ignore
# 10 $userAgent – user agent string
# 11 $visitorId – unique visitor id
# 12 $sessionId – session id. Expires when the browser window is closed
# 13 $isResearch –                                                                            Ignore
# 14 $ProviderURL – URL used to query Yellowbook API.

puts '(c) Copyright 2009 VenueSoftware Corp. All Rights Reserved. '

FILTER_NAME = "filter_repeated_IPs"
QRY_FILE = ARGV[0] ||= "qry_file_in.txt"                            #input
QRY_FILE_OUT = ARGV[1] ||= "qry_file_out.txt"                       #default output file name
QRY_LIMIT = ARGV[2] ||= 100000000                                   #limit queries to read

CLIENT_IP = 6
lines = 0
matches = 0 
@count_unique_IPs = 0
@count_repeated_IPs = 0

# Count first occurance in a series only, but CONSIDER searches might not be same so we undercount unique searches this way
def check_repeats(l)  
  repeat = false
  if @have_IP == @fields[6].to_s
    @count_repeated_IPs += 1
    @log.write( "\t __REPEATED__\n")  if @diagnostics
    repeat = true
   else
    @have_IP = @fields[6].to_s
    @count_unique_IPs += 1
  end
  repeat
end

started_at = Time.new
if !File.exists?(QRY_FILE)
  puts "Input file does not exist, please re-try with the name of an input file."
  Kernel.exit!
end
@log = File.open("log.txt", "a") 
@o = File.open(QRY_FILE_OUT, modestring = "w")

puts "File: " + QRY_FILE + "\n______________________________________________\n"
puts "File size: " + File.stat(QRY_FILE).size.to_s + " bytes\n"
puts "Began at: " + Time.now.to_s + "\n"

#READ LOOP
#
File.open(QRY_FILE, modestring = "r") do |f|
  f.each($/) do |line|
    lines += 1    
    if lines > QRY_LIMIT.to_i
      puts "Terminated, reached limit at #{QRY_LIMIT}"
      Kernel.exit
    end
    
    @fields = line.split("\t")    
    if !check_repeats(line)
      @o.write(line)
    end
    
    puts FILTER_NAME + ": " + lines.to_s + "\trecords @\t" + Time.new.to_s if lines.modulo(100000)  == 0
  #end of read block    
  end
#end of file block
end 


#Record the results in file f
completed_at = Time.new
  
@log.write( "\n\nFilter: \t\t\t\t\t\t" + FILTER_NAME + "\n______________________________________________\n")
@log.write( "File size: \t\t\t\t\t\t" + File.stat(QRY_FILE).size.to_s + " bytes\n")
@log.write( "Began at: \t\t\t\t\t\t" + started_at.to_s + "\n")
@log.write( "Completed: \t\t\t\t\t\t" + completed_at.to_s + "\n") 
@log.write( "Input file name: \t\t\t\t" + QRY_FILE + "\n")
@log.write( "Input file count: \t\t\t\t" + lines.to_s + "\n")
@log.write( "Output file name: \t\t\t\t" + QRY_FILE_OUT + "\n")
@log.write( "Count of not repeated IPs:\t\t" + @count_unique_IPs.to_s + "\n")
@log.write( "STATUS REPEATED = \t\t\t\t" + @count_repeated_IPs.to_s + "\n")
@log.write( "total seconds:\t\t\t\t\t" + "%.3f" % (completed_at - started_at).to_f + "\n")
@log.write( "average records per second:\t\t" + "%.3f" %  (lines/(completed_at - started_at)).to_f + "\n" )
@log.write("__END__\n")
@log.write( '(c) Copyright 2009 VenueSoftware Corp. All Rights Reserved. ')


@log.close

#
# Report the results recorded in log.txt
#  
puts "\n"
File.open("log.txt", "r") do |f|
  while line = f.gets
    puts line
  end
@o.close()


#END
end

