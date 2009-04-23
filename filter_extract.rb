# #!/usr/local/bin/ruby
#                    
#filter_extract.rb
# Function -- Script simply counts and optionally extracts records from a log
#          -- EXTRACT_FILE.nil? counts records in QRY_FILE
#          -- EXTRACT_FILE.exists && MATCH_ON.exists, count and extract records with MATCH_ON to EXTRACT_FILE
# Filter Sequence to run
# script                   default in          default out          discussion                                                       status determined
# ______________           ______________      _________________    _____________________________________________________________    _________________
# filter_extract           qry_file_in         qry_file_out         reads any qry file, removes/writes matches on MATCH_ON string    STATUS_COUNT
# filter_unique_domains    qry_file_in         none                 reads any qry file, logs frequency distribution unique domains   STATUS_COUNT
# filter_bots              qry_file_out        qry_file_bots_out    reads any qry file, bots counted and removed from output         STATUS_BOTS
# filter_inUS              qry_file_bots_out   qry_file_isUS_out    reads raw or filtered, removes locations not in US               STATUS_NOWHERE
# filter_repeated_IPs      qry_file_isUS_out   qry_file_notRep_out  reads raw or filtered, removes repetitive incoming IPs           STATUS_REPEATS
# filter_count             qry_file_notRep_out none                 reads any qry file, EXTRACT_ON = nil (just count)                STATUS_OK                              

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


QRY_FILE = ARGV[0] ||= "qry_file_in.txt"                            #default input file
QRY_FILE_OUT = ARGV[1] ||= "qry_file_out.txt"                       #default output file
MATCH_ON = /www101.tuk.intelius.com-yp-searches.log.12022008.gz/    #match on this server on Dec 02, 2008
#QRY_FILE = "Oct08_Extract_20000.txt"                               #input--development testing
#QRY_FILE = "yb-searches-October.txt"                               #input--Production, whole month
#QRY_FILE = "E:/Webaudits/Intelius/Dec09/12022009log.txt"  #changes, for use on server


lines = 0
matches = 0

started_at = Time.new
if !File.exists?(QRY_FILE)
  puts "Input file does not exist, please re-try with the name of an input file."
  Kernel.exit!
end
@log = File.open("log.txt", "w") 
puts "Script:  intelius_count.rb"
puts "File: " + QRY_FILE
puts "File size: " + File.stat(QRY_FILE).size.to_s + " bytes\n"
puts "Began at: " + Time.now.to_s + "\n"
@o = File.open( QRY_FILE_OUT, "w")
#READ LOOP
File.open(QRY_FILE, modestring = "r") do |f|
  f.each($/) do |line|
    lines += 1
    unless line.match(MATCH_ON).nil?
      @o.write(line)
      matches += 1
      puts matches.to_s + "\tmatched records @\t" + Time.new.to_s if matches.modulo(10000)  == 0
    end
    
    puts lines.to_s + "\trecords @\t" + Time.new.to_s if lines.modulo(100000)  == 0
  #end of read block    
  end
#end of file block
end 


#Record the results in file f
  completed_at = Time.new
  
  @log.write("\n\nCompleted: " + completed_at.to_s + "\n") 
  @log.write( "Input file: \t\t" + QRY_FILE + "\n")
  @log.write( "Count read: \t\t" + lines.to_s +  "\n\n" ) 

  @log.write( "Output file:\t\t" + QRY_FILE_OUT + "\n")
  @log.write( "Count out (matched):\t" + matches.to_s + "\n")


@log.write( "\n" + "%.3f" %                                      (completed_at - started_at).to_f + "\ttotal seconds to process QRY_FILE\n")
@log.write( "%.3f" %                                             (lines/(completed_at - started_at)).to_f + "\taverage records per second.\n" )
@log.write("\n__END__\n")

@log.close

#
# Report the results recorded in log.txt
#  
puts "\n"
File.open("log.txt", "r") do |f|
  while line = f.gets
    puts line
  end

#END
end

