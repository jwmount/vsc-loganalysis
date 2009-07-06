#QClass = Class.new
#module QCLASS
# (c) Copyright 2009 VenueSoftware Corp. All Rights Reserved.
class QClass
  UA_ID = 10
  UA_id = 9  #remove this soon
  QRY_type = 5
  QUERY_RETRY = '7'
  QUERY_VALID = 15
  QUERY_FIELDS = 16     #number of fields in query record
  attr_reader :count, :UA_id, :file_in, :qry_file, :started_at, :limit, :milestone
  
  def aqps
    "%3.0f" %  (@count/(Time.new - @started_at)).to_f
  end
  def initialize ( file_in, file_out, limit)
    @count = 0
    @lines_out = 0
    @limit = limit
    @milestone = "."
    @file_in = file_in
    @file_out = file_out
    @log = File.open("log.txt", "a") 
    @started_at = Time.new
    puts "\n\n\nFilter\t\t\t\t#{$0}\n________________________________________________________"
    puts '(c) Copyright 2009 VenueSoftware Corp. All Rights Reserved. '
    if !File.exists?(file_in)
      puts "\nFile-in:\t\t\t#{file_in} NOT FOUND, please correct the input file name and try again.\n"
      Kernel.exit!
    end
    puts "\nFile name:\t\t\t" + file_in + "\n"
    @o = File.open(file_out, modestring = "w+") if file_out.length > 0
    puts "Started:\t\t\t" + Time.now.to_s
  end

  def comment? l
    l =~ /\*/
  end
      
  def inc_count
      @count = (@count ||= 0) + 1
  end

  def count_asString
      @count.to_s
  end
  
  def limit? 
    if @count == @limit.to_i
      wrap_up("Terminated, reached limit of\t\t#@limit\n")
      Kernel.exit 99
    end
    inc_count
  end
    
  def log l
    @log.write l
  end

  def param_is_blank(f)
    result = true
    begin
      w = f.split("&")
      result = false if w[0].length > 0 
    rescue NoMethodError
      log( "On query: #@count\tSearch by query or by phone but query parameter is:\tfield: #{f}")
      log( milestone )
    return result
    end
  end
  
  def progress?
    if @count.modulo(10000) == 0
      puts $PROGRAM_NAME + "\t" + @count.to_s +  "\tqueries @" +  aqps + " queries/sec in " + "%3.1f" % (Time.now - @started_at).to_s + " seconds" + milestone
    end
  end
  
  def milestone=(m)
    @milestone = ( m ||= ".")
  end
  
  def wrap_up(r)
    completed_at = Time.new
    @o.close()
    log( "\n\n\nFilter\t\t\t\t\t\t\t\t#{$0}" + "\n________________________________________________________\n")
    log( "File name:\t\t\t\t\t\t\t#{@file_in}\n")
    log( "File out name:\t\t\t\t\t\t#{@file_out}\n")
    log( "Started:\t\t\t\t\t\t\t" + @started_at.to_s  + "\n")
    log( "Completed:\t\t\t\t\t\t\t" + completed_at.to_s + "\n") 
    log( r )
    log( "Queries Removed:\t\t\t\t\t" + "%d" % (@count - @lines_out).to_f + "\n" )
    log( "Queries written: \t\t\t\t\t" + "%d" % @lines_out + "\n")
    log( "Queries read (total): \t\t\t\t" + "%d" % @count + "\n")
    log( "Total seconds\t\t\t\t\t\t" + "%.3f" %  (completed_at - @started_at).to_f + "\n" )
    log( "Average records per second:\t\t\t" + aqps +  "\n" )
    log( "__END__\n")
    log( "(c) Copyright 2009 VenueSoftware Corp. All Rights Reserved. \n")
    @log.close
    puts "\n"
    File.open("log.txt", "r") do |f|
      while line = f.gets
        puts line
      end
    end
  end
  
  def write l
    @o.write(l)
    @lines_out += 1
  end
  
  def help
  # Filter Sequence to run
  # script                   default in          default out          discussion                                                       status determined
  # ______________           ______________      _________________    _____________________________________________________________    _________________
  # filter_extract           qry_file_in         file_out             reads any qry file, removes/writes matches on MATCH_ON string    STATUS_COUNT
  # filter_unique_domains    qry_file_in         none                 reads any qry file, logs frequency distribution unique domains   STATUS_COUNT
  # filter_bots              file_out            qry_file_bots_out    reads any qry file, bots counted and removed from output         STATUS_BOTS
  # filter_inUS              qry_file_bots_out   qry_file_isUS_out    reads raw or filtered, removes locations not in US               STATUS_NOWHERE
  # filter_repeated_IPs      qry_file_isUS_out   qry_file_notRep_out  reads raw or filtered, removes repetitive incoming IPs           STATUS_REPEATS
  # filter_count             qry_file_notRep_out none                 reads any qry file, EXTRACT_ON = nil (just count)                STATUS_OK                              
  # filter_valids            qry_file_bots_out   qry_file_valids_out  counts Yellowbook queries accepted                               STATUS_VALID
  # 0  $date time – date and time of request with em bedded space
  # 1  $site – This is our internal site id. We have dozens of sites that use yellowbook API.   Ignore
  # 2  $referId – This is our internal lead tracking number.                                    Ignore
  # 3  $provider – This is always 107 (yellowbook API)                                          Ignore
  # 4  $searchType – This will have values between 11 and 14.                                   Ignore
  # 5  $queryType – This field can have one of these values: -1 (API returned an error), 1(multi results page), 2(no results found), 
  #                 3(details or more info page), 4 (next page using pagination), 5(this search is same as previous search – search is repeated), 
  #                 7 query retry
  #                 11 (search resulted in category listings).
  # 6  $clientIp – client IP addresses
  # 7  $isBot – We consider this request is from a bot. This is according to our definition. Your definition might be different.  Ignore
  # 8  $_SERVER['HTTP_HOST'] – requested domain name.                                           Ignore
  # 9  $_SERVER['REQUEST_URI'] – requested URI.                                                 Ignore
  # 10 $userAgent – user agent string
  # 11 $visitorId – unique visitor id
  # 12 $sessionId – session id. Expires when the browser window is closed
  # 13 $isResearch –                                                                            Ignore
  # 14 $ProviderURL – URL used to query Yellowbook API.
  # 15 $YB_api_errors - error codes from Yellowbook API.  Valid if missing or == '0'.  Added mid-May, 2009
  end

end

