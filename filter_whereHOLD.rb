# #!/usr/local/bin/ruby
# USED FOR MARCH ANALYSIS, enhanced for APRIL with QClass version
#filter_where.rb
# Function --  Filter out queries by type
#          -- qry is STATUS_NOWHERE is a misnomer, use filter_isUS if actual location in US is of interest.
#          -- qry is STATUS_NOWHERE if SEARCHTYPE == 14 and the value for &PN= in ProviderURL is blank
#          -- qry is STATUS_NOWHERE if QUERYTYPE == 3 and the value for &id= in ProviderURL is blank.
#          -- qry is STATUS_NOWHERE if SEARCHTYPE != 14 or QUERYTYPE != 3 and either &what= or &where= in ProviderURL is blank.
# Filter Sequence to run
# script                   default in          default out          discussion                                                       status determined
# ______________           ______________      _________________    _____________________________________________________________    _________________
# filter_extract           qry_file_in         qry_file_out         reads any qry file, removes/writes matches on MATCH_ON string    STATUS_COUNT
# filter_unique_domains    qry_file_in         none                 reads any qry file, logs frequency distribution unique domains   STATUS_COUNT
# filter_bots              qry_file_out        qry_file_bots_out    reads any qry file, bots counted and removed from output         STATUS_BOTS
# filter_inUS              qry_file_bots_out   qry_file_isUS_out    reads raw or filtered, removes locations not in US               STATUS_NOWHERE  misnomer
# filter_repeated_IPs      qry_file_isUS_out   qry_file_notRep_out  reads raw or filtered, removes repetitive incoming IPs           STATUS_REPEATS
# filter_count             qry_file_notRep_out none                 reads any qry file, EXTRACT_ON = nil (just count)                STATUS_OK 
# filter_where             qry_file_bots_out   qry_file_qryOK_out   reads any qry file, removes any with no valid type               STATUS_NOWHERE                             

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

puts "\n\n\nFilter: filter_where\n____________________"
puts '(c) Copyright 2009 VenueSoftware Corp. All Rights Reserved. '

FILTER_NAME = "filter_where"
QRY_FILE = ARGV[0] ||= "qry_file_bots_out.txt"                      #input
QRY_FILE_OUT = ARGV[1] ||= "qry_file_out.txt"                       #default output file name
QRY_LIMIT = ARGV[2] ||= 100000000                                   #limit queries to read
STATUS_NO_WHERE = 3
STATUS_OK = 0

@diagnostics = true
@geo_filters = [/&where=/,/&what/, /&id/]
@lines = 0
lines_out = 0
no_where = 0
status = STATUS_OK
location = []
fields = []

def param_is_blank(f)
  result = true
  begin
    w = f.split("&")
    @o.write w
    result = false if w[0].length > 0 
  rescue NoMethodError
    @log.write( "NoMethodError on line: #{@lines}\nfield: #{f}")
#  return w[0].length > 0 ? false : true  remove this once exception handler proven out
  return result
  end
end

started_at = Time.new
if !File.exists?(QRY_FILE)
  puts "Input file does not exist, please re-try with the name of an input file."
  Kernel.exit!
end
@log = File.open("log.txt", "a") 
@o = File.open(QRY_FILE_OUT, modestring = "w")

puts "Filter\t\t\t\t\t#{FILTER_NAME}\n______________________________________________\n"
puts "Input file name: " + QRY_FILE 
puts " size: " + File.stat(QRY_FILE).size.to_s + " bytes"
puts "Output file name: " + QRY_FILE_OUT
puts "Started: " + started_at.to_s

#READ LOOP
#
File.open(QRY_FILE, modestring = "r") do |f|
  f.each($/) do |@line|
    @lines += 1   
    if @lines > QRY_LIMIT.to_i
      puts "Terminated, reached limit at #{QRY_LIMIT}"
      Kernel.exit
    end
 
    fields = @line.split("\t")
    status = STATUS_OK

  # more info page
  if fields[5] == '3' 
    id = @line.split("&id=")
    if param_is_blank(id[1])
      status = STATUS_NO_WHERE
    end
  end

  # phone search
  if fields[4] == '14'
    pn = @line.split("&PN=")
    if param_is_blank(pn[1])
      status = STATUS_NO_WHERE
    end
  end

  # what or where    
  if @geo_filters[0].match(@line) || @geo_filters[1].match(@line)
    location = @line.split("&what=")
    if param_is_blank(location[1])
      status = STATUS_NO_WHERE
    end
    location = @line.split("&where=")
    if param_is_blank(location[1])
      status = STATUS_NO_WHERE
    end
  end
  if status == STATUS_OK
    @o.write( @line )
    lines_out += 1
  else
    no_where += 1
  end
  puts FILTER_NAME + ": " + @lines.to_s + "\trecords \t" + Time.new.to_s if @lines.modulo(100000)  == 0
  #end of read block    
  end
#end of file block
end 

#Sandeep's logic for STATUS_NOWHERE:
#-------------------------------------
 
#if(QUERYTYPE == 3) //more info page
#{
#  If(id_parameter_in_providerURL_is_blank)
#    status = STATUS_NOWHERE;
#}
#elseIf(SEARCHTYPE == 14) //phone search
#{
#  If(PN_parameter_in_providerURL_is_blank)
#      Status = STATUS_NOWHERE;
#}
#Elseif(what_parameter_in_providerURL_is_blank OR where_parameter_in_providerURL_is_blank)
#  Status = STATUS_NOWHERE;

#Record the results in file f
completed_at = Time.new

@log.write( "\n\nFilter\t\t\t\t\t\t\t#{FILTER_NAME}\n______________________________________________\n")
@log.write( "Input file name: \t\t\t\t" + QRY_FILE + "\n" )
@log.write( "Size: \t\t\t\t\t\t\t" + File.stat(QRY_FILE).size.to_s + " bytes\n" )
@log.write( "Output file name: \t\t\t\t" + QRY_FILE_OUT + "\n" )
@log.write( "Started: \t\t\t\t\t\t" + started_at.to_s + "\n" )
@log.write( "Completed:\t\t\t\t\t\t" + completed_at.to_s + "\n") 
@log.write( "Queries read:\t\t\t\t\t" + @lines.to_s + "\n")
@log.write( "STATUS NOWHERE: \t\t\t\t" + no_where.to_s + "\n")
@log.write( "STATUS OK:\t\t\t\t\t\t" + (lines_out).to_s + "\n")
@log.write( "Total seconds:\t\t\t\t\t" + "%.3f" % (completed_at - started_at).to_f + "\n")
@log.write( "Average records per second \t\t%.3f" %  (@lines/(completed_at - started_at)).to_f + "\n" )
@log.write("__END__\n")

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

