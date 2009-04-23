# #!/usr/local/bin/ruby
#                    
#filter_repeated.rb
# Function -- filter out repeated queries in a session, i.e. count as one query
# Filter Sequence to run (all file types are .txt)
#
# Filter Sequence to run
# script                   default in          default out          discussion                                                       status determined
# ______________           ______________      _________________    _____________________________________________________________    _________________
# filter_extract           qry_file_in         qry_file_out         reads any qry file, removes/writes matches on MATCH_ON string    STATUS_COUNT
# filter_unique_domains    qry_file_in         none                 reads any qry file, logs frequency distribution unique domains   STATUS_COUNT
# filter_bots              qry_file_out        qry_file_bots_out    reads any qry file, bots counted and removed from output         STATUS_BOTS
# filter_inUS              qry_file_bots_out   qry_file_isUS_out    reads raw or filtered, removes locations not in US               STATUS_NOWHERE  misnomer
# filter_repeated_IPs      qry_file_isUS_out   qry_file_notRep_out  reads raw or filtered, removes repetitive incoming IPs           STATUS_BOTS
# filter_repeated          qry_file_in         qry_file_out         reads raw or filtered, removes repeated queries within a session STATUS_REPEATS
# filter_count             qry_file_notRep_out none                 reads any qry file, EXTRACT_ON = nil (just count)                STATUS_OK 
# filter_where             qry_file_bots_out   qry_file_qryOK_out   reads any qry file, removes any with no valid type               STATUS_NOWHERE                          

# QRY_FILE format
# 0  $date time – date and time of request with embedded space
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

FILTER_NAME = "filter_repeated"
QRY_FILE = ARGV[0] ||= "qry_file_in.txt"                            #input
QRY_FILE_OUT = ARGV[1] ||= "qry_file_out.txt"                       #default output file name
QRY_LIMIT = ARGV[2] ||= 100000000                                   #limit queries to read
STATUS_INVALID_SEARCH = "*"
STATUS_REPEATSEARCH = "2"
STATUS_OK = "0"
DIAGNOSTICS = false
SESSION_LENGTH = 1200                                              # 20 minutes
PURGE_LENGTH = SESSION_LENGTH / 2                                  # arbitrary, about hwm

status = STATUS_OK
lines = 0
lines_out = 0
fields = []
what = ""
where = ""
visits_in_session = {}
newIP = {}
@value = 0
@count_repeated = 0
count_repeated_2 = 0
@IPaddress = ""
@visit = ""
hwm = 0
purge = 0

# sessionID, IPaddress, what, where   queries
# 11111     1.1.1.1     nails Napa      1
# 11111     1.1.1.1     hair  Sonoma    2
# 22222     1.1.1.2     hair  Sonoma    3
# 11111     1.1.1.1     hair  Sonoma    3
# queries = [IP, sessionID, what, where]
# uniques = { queries => value }
# If it is term search, then we need: Sessionid, what, where, page number, sort order etc…
# If it is term search more info page, then we need: Sessionid, what, where, RecId etc…
# If it is reverse phone search, then we need: sessionid, phone number, page number, sort order etc…
# If it is reverse phone more info, then we need: sessionid, phone number, recid etc…
# Algorithm -- session length search framework; search domain never more than visits in last xxx minutes
# new visit
#   scan session frame, remove anything older than time for this visit - session length
#   then
#     have we seen this visit (in last session.length minutes)?
#     NO
#       add it to frame
#     YES
#       status == STATUS_REPEATED
#   end
#   count_repeated += 1 if STATUS_REPEATED
def param_is_blank(f)
  w = f.split("&")
  return w[0].length > 0 ? false : true
end

started_at = Time.new
if !File.exists?(QRY_FILE)
  puts "Input file does not exist, please re-try with the name of an input file."
  Kernel.exit!
end
@log = File.open("log.txt", "a") 
@o = File.open(QRY_FILE_OUT, modestring = "w")

puts "\n\nFilter:\t\t\t\t" + FILTER_NAME + "\n__________________________________________________"
puts '(c) Copyright 2009 VenueSoftware Corp. All Rights Reserved. '
puts "Input file:\t\t\t" + QRY_FILE
puts "Size: \t\t\t\t" + File.stat(QRY_FILE).size.to_s + "\n"
puts "Output file:\t\t\t" + QRY_FILE_OUT
puts "Session length (seconds):\t" + SESSION_LENGTH.to_s
puts "Started:\t\t\t" + Time.now.to_s

#READ LOOP
#
File.open(QRY_FILE, modestring = "r") do |f|
  f.each($/) do |line|
    lines += 1   
    if @lines > QRY_LIMIT.to_i
      puts "Terminated, reached limit at #{QRY_LIMIT}"
      Kernel.exit
    end
    
    status = STATUS_OK
    fields = line.split("\t") 
      
    # more info page based on QUERYTYPE More Info
    if fields[5] == '3' 
      id = line.split("&id=")
      status = STATUS_INVALID_SEARCH if param_is_blank(id[1])
      @count_repeated += 1      
      next
    end
    
    # phone search based on SEARCHTYPE_BYPHONE
    if fields[4] == '14'
      pn = line.split("&PN=")
      status = STATUS_INVALID_SEARCH if param_is_blank( pn[1] )
      @count_repeated += 1
      next
    end

    if status == STATUS_OK
    
      # this is the fun part, it's an info query
      # have we seen this visit before?  If so, how long ago?
      # is query a repeat?    

      sessionID = fields[12]
#      @IPaddress = fields[6]
      begin
        providerURL = fields[14].split("&")
      rescue
        puts "NoMethodError on line: #{lines}\n#{line}"
        @log.write( "NoMethodError on line: #{lines}\n#{line}")
        next
      end
      what = providerURL[7] ||= nil
      where = providerURL[8] ||= nil
      if what.nil? || where.nil?
        status = STATUS_INVALID_SEARCH
        @count_repeated += 1
        next
      end
    


    @visit = what + where + sessionID
    dt = fields[0].split("gz:")
    tm = dt[1].split(" ")
    d = dt[1].split("-")
    yr = d[0]
    mo = d[1]
    day = d[2]
    t = tm[1].split(":")
    hr = t[0]
    min = t[1]
    sec = t[2]
    time = Time.local( yr, mo, day, hr, min, sec )
     
    # is query repeated?  if yes, is STATUS_REPEATSEARCH
    if visits_in_session.has_value?(@visit)
      status = STATUS_REPEATSEARCH
      hwm = visits_in_session.length if visits_in_session.length > hwm
    else
      visits_in_session.update(time => @visit)
      puts "newIP added: " + visits_in_session[time] + "\tcount: " + visits_in_session.length.to_s     if DIAGNOSTICS
    end
    
    # using purge to limit session trash collection lets the collection length vary
    # consider if this will cause the counts of STATUS_REPEATED to be higher than they should be.
    # Perhaps not given that a query sessionID will change after SESSION_LENGTH seconds and so not be found.
    # remove any queries older than time (of this one minus SESSION_LENGTH)
    purge += 1
    if purge >= PURGE_LENGTH
#      puts 'before purge visits_in_session was: ' + visits_in_session.length.to_s
      visits_in_session.delete_if { |k,v| (time - SESSION_LENGTH) > k }
#      puts 'after purge visits_in_session is: ' + visits_in_session.length.to_s + "\n\n"
      purge = 0
    end      
  end
  
  puts "status: " + status + "\t" + @visit if DIAGNOSTICS
  if status == STATUS_OK
    lines_out += 1
    @o.write( line )
  else
    @count_repeated += 1
  end
  puts  FILTER_NAME + ": " + lines.to_s + "\trecords @\t" + Time.new.to_s + "\thigh water mark: " + hwm.to_s + 
    "\t" + "current items in session: " + visits_in_session.length.to_s  if lines.modulo(10000)  == 0
  #end of read block    
  end
#end of file block
end 

completed_at = Time.new
@log.write( "\n\nFilter:\t\t\t\t\t" + FILTER_NAME + "\n__________________________________________________\n")
@log.write( "(c) Copyright 2009 VenueSoftware Corp. All Rights Reserved. \n")
@log.write( "Input file:\t\t\t\t" + QRY_FILE + "\n")
@log.write( "Size: \t\t\t\t\t" + File.stat(QRY_FILE).size.to_s + "\n" )
@log.write( "Output file:\t\t\t" + QRY_FILE_OUT + "\n" )
@log.write( "Session length:\t\t\t" + SESSION_LENGTH.to_s + " seconds\n" )
@log.write( "Started:\t\t\t\t" + started_at.to_s + "\n")
@log.write( "Completed:\t\t\t\t" + completed_at.to_s + "\n")
@log.write( "Queries read:\t\t\t" + lines.to_s + "\n")
@log.write( "STATUS REPEATED:\t\t" + @count_repeated.to_s + "\n")
@log.write( "STATUS OK:\t\t\t\t" + lines_out.to_s + "\n" )
@log.write( "High water mark:\t\t" + hwm.to_s + "\n")
@log.write( "Total seconds:\t\t\t" + "%.3f" % (completed_at - started_at).to_f + "\n" )
@log.write( "Queries/second:\t\t\t" + "%3.3f" % (lines/(completed_at - started_at)).to_f + "\n" )
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

