#                    
#analysis.rb -- Intelius log analyzer.
#opyright VenueSoftware Corp. 2008

#To Do:
#1.  Extend the list of process types from 'bot' and 'crawl' to include others, e.g. 'slurp'
#2.  Consider a more general design so that we do a frequency distribution of one list versus another for some set of attributes in a log.
#    example:  
#      @user_agent = i --> i is index into array created when record is split
#      @names = { "bot", 0, "crawl", 0, "slurp", 0 ]  hash of bot id tokens, each record is examined for all of these and they can be counted when found.
#      @domains = {"addresses.com",0,"cox.net",0} hash of domains we care about; if COLLECT_ALL, add as encountered using @domains.merge!(new_domain)
#     
#     domains   Included    Bots&Crawlers    Total
#               (rejected)      
#     iaf.net     nnn,nnn     bbb,bbb        ttt,ttt   
#     cox.net     nnn,nnn     bbb,bbb        ttt,ttt   
#                 ...                       
#     totals      NNN,NNN     MMM,MMM        TTT,TTT                     
#

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

#require 'socket'                       #activate to do reverse DNS lookups
#QRY_FILE = "extracticul.txt"          #use to verify 14 delimiters, provided to Sandeep via email 12/30/08
#QRY_FILE = "Oct08_head.txt"
#QRY_FILE = "Oct08_Extract_1000.txt"  #development testing
QRY_FILE = "Oct08_Extract_20000.txt" #development testing
#QRY_FILE = "yb-searches-October.txt" #Production, whole month
#QRY_FILE = "E:/Webaudits/Intelius/OctoberInteliusWebRequests.txt"  #changes, for use on server

@diagnostics = true                   #NOTE:  switched off after 1000 queries, not constant
@diag_limit = 1000                       
COUNT_BOTS = true
COUNT_REQUESTED_CLIENT_DNAMES = true
COUNT_UNIQUE_DNAMES = false          #NOTE:  slow, conducts reverse domain name lookups
COUNT_INTELIUS_DNAMES_ONLY = false   #NOTE:  to take effect, COUNT_UNIQUE_DNAMES must also be true
DN_ID = 8
UA_ID = 10

@bot_hash = {} 
@isCovered = false
@bots = 0
@domains = {}
@count_unique_IPs = 0
@count_repeated_IPs = 0
@have_IP = "no"    
@lines = 0
@count_covered_comains = 0
@count_not_covered_comains = 0
@outcome = ""
@count_covered_and_bot = 0
@thisDN = ""
@fields = []
@covered_domans = [ "addresses.com", "iaf.net", "areaconnect.com", "yellow.com", "findlinks.com", "phonebook.com", "electricyellow.com", "whitepage.net", 
                         "pumpkinpages.com", "uscity.net", "numberway.com", "reversephonedirectory.com", "oregon.com", "wnd.com", "zabasearch.com"]

log = File.open("log.txt", "w") 
if @diagnostics 
  log.write( "File: " + QRY_FILE)
  log.write( "File size: " + File.stat(QRY_FILE).size.to_s + " bytes\n")
  log.write( "Diagnostics ON with DIAG_LIMIT = " + @diag_limit.to_s + "\n")
  log.write( "DN_ID is: " + DN_ID.to_s + " UA_ID is: " + UA_ID.to_s  )
  log.write( "Began at: " + `date` + "\n")
else
  puts "File: " + QRY_FILE
  puts "File size: " + File.stat(QRY_FILE).size.to_s + " bytes\n"
  puts "Diagnostics are OFF\n"
  puts "DN_ID is: " + DN_ID.to_s + " UA_ID is: " + UA_ID.to_s
  puts "Began at: " + `date` + "\n"
end
#
#READ LOOP
#
started_at = Time.new
puts started_at
test = 0
File.open(QRY_FILE, modestring = "r") do |f|
  f.each($/) do |line|  
  @lines = @lines + 1
  @fields = line.split("\t")        
  @diagnostics = false if @lines > @diag_limit 
  @outcome = @lines.to_s + "\t" + @fields[6].to_s + "\t" if @diagnostics

  re = /(addresses.com)/
  md1 = re.match(line)
  test = test + 1 if md1
  next
  #  ClientIP addr is not from a covered domain.  
  # Take inventory of queries from unique IP addresses 
  # Count first occurance in a series only, but CONSIDER searches might not be same so we undercount unique searches this way
    if @have_IP == @fields[6].to_s
      @count_repeated_IPs = @count_repeated_IPs + 1
      @outcome << "Repeated (skipped).\t"  if @diagnostics
      next unless @diagnostics
    else
      @have_IP = @fields[6].to_s
      @count_unique_IPs = @count_unique_IPs + 1
      @outcome << "New  " if @diagnostics
    end

  # COUNT_REQUESTED_CLIENT_DNAMES
	if COUNT_REQUESTED_CLIENT_DNAMES
	  @outcome << "items: " + @fields.nitems.to_s + " " if @diagnostics
	  @fields[DN_ID] = "none.com" if @fields[DN_ID].nil?
	  ua_fields = @fields[DN_ID].to_s.split(".").last(2)
	  dn = ua_fields[0].to_s + "." + ua_fields[1].to_s
    @outcome << "domain name: " + dn + " " if @diagnostics
	  if @covered_domans.include?(dn) 
	    @count_covered_comains = @count_covered_comains + 1
	    @isCovered = true
	  else
	    @count_not_covered_comains = @count_not_covered_comains + 1
	    @outcome << "NOT " if @diagnostics
	    @isCovered = false
    end
	  @outcome <<  "COVERED.\t" if @diagnostics
  end

  #  BOTS and CRAWLERS
  #  Exclude BOTS, other PROCESSES etc.    
  #  Exclude user-agent (Googlebot); reference http://www.google.com/support/webmasters/bin/answer.py?answer=80553 --> "The best way to identify accesses by Googlebot is to use the user-agent (Googlebot)."
  #  Get distribution of excluded bots, also count all bot exclusions
  if COUNT_BOTS
    if ( @fields[UA_ID].to_s.include?("bot") || @fields[UA_ID].to_s.include?("crawl") ) 
      @bots = @bots + 1
      @count_covered_and_bot = @count_covered_and_bot + 1 if @isCovered
      @outcome << "\t__BOT__" if @diagnostics
      if !@bot_hash.has_key?(@fields[UA_ID])   #if not in hash yet, add it
        newbotH = {@fields[UA_ID]=>1}
        @bot_hash.update(newbotH)
      else                                  #if is, increment value and next record
        @bot_hash[ @fields[UA_ID] ] = @bot_hash.fetch( @fields[UA_ID] ) + 1
        next                      
      end
    end
  end
  
#   Collect hash of unique domain names
  # if collect_intelius is true
  if COUNT_UNIQUE_DNAMES
    serverInfo = Socket.getaddrinfo(@fields[UA_ID], 'http') rescue {}
    if serverInfo.to_s.match("localhost")
      @thisDN = "localhost"
    else
      a = serverInfo[0][2].scan(/\w+/) 
      d = a.last(2)
      @thisDN = d[0] + '.' + d[1]
    end

    if COUNT_INTELIUS_DNAMES_ONLY   #only ones in @covered_domans array
      if !@covered_domans.include?(@thisDN)
        @thisDN = "excluded"
      end    
    end
    
    unless @domains.has_key?(@thisDN)
      newDN = {@thisDN => 1}
      @domains.merge!(newDN) {|k, o, n| o }
    else
      @domains[ @thisDN ] = @domains.fetch( @thisDN ) + 1
    end
  end

  log.write( @outcome + "\n") if @diagnostics
#end of read block    
end
#end of file block
end 

#f.close()

#Record the results in file f
  completed_at = Time.new
  
  log.write("\n\nCompleted: " + `date` + "\n") 
  log.write( @lines.to_s + " queries (records) in QRY_FILE \n\n" ) 
  log.write( "Unique IP addresses\n---------------------------\n(based on change in IP in sequence; only first one counted)\n\n")
  log.write( "  " + @count_unique_IPs.to_s + "\tunique IPs\n" )
  log.write( "  " + @count_repeated_IPs.to_s + "\tnon unique IP addresses (skipped)\n" )
  log.write( "  " + (@count_unique_IPs + @count_repeated_IPs).to_s + "\ttotal\n")

  # COUNT_UNIQUE_DNAMES
  if COUNT_UNIQUE_DNAMES
      if COUNT_UNIQUE_DNAMES 
        count_domains = 0
        log.write( "\nFrequency of queries by domain name\n-----------------------------------------\n\n" )
        @domains.each do |key, value|
          log.write( value.to_s + ' \t' + key + "\n" )
          count_domains += 1
        end
        log.write( count_domains.to_s + " unique domains in file\n" )
      end
    end

  # counts of covered (in list) and not covered (not in list) domains
  log.write( "\nListed domain request counts\n----------------------------\n")
  log.write( @count_covered_comains.to_s + "\ttotal convered domains (in list).\n")
  log.write( @count_not_covered_comains.to_s + "\tnot covered (not in list).\n")
  log.write( (@count_covered_comains + @count_not_covered_comains).to_s + "\ttotal queries were identified in QRY_FILE.\n")
  
  
  # COUNT_BOTS
    if COUNT_BOTS
        log.write( "\nRobot and Crawler counts\n-------------------------\n")
        log.write( @bot_hash.length.to_s + "\tdistinct bots and crawlers were identified in QRY_FILE.\n\n")
        log.write( "\tFrequency distribution as follows:\n\n" )
        @bot_hash.each do |key,value|
          log.write( "  " + value.to_s + "\t" + key + "\n")
        end
        log.write( @bots.to_s + "\tTotal bots and crawlers identified.\n\n" )
        
        log.write( "\n" + @count_covered_and_bot.to_s + "\tCovered queries were by bots.\n")
        log.write( "\n" + (@count_covered_comains + @count_not_covered_comains - @count_covered_and_bot).to_s + 
                   "\tnet total queries in Intelius domains (listed below).\n----------------------------------------------\n\n" )
    end

  # COUNT_INTELIUS_NAMES_ONLY 
      if COUNT_REQUESTED_CLIENT_DNAMES
      end
    

  # COUNT_INTELIUS_DNAMES_ONLY -- REQUIRED TO ALSO set COUNT_REQUESTED_CLIENT_NAMES true
      if COUNT_INTELIUS_DNAMES_ONLY
        @count_covered_comains = 0
        log.write( "\nFrequency of covered domains\n----------------------------\n\n" ) 
        @covered_domans.each do |key, value|
          if @domains.has_key?(key)
            log.write(key + "  found\n" )
            @count_covered_comains = @count_covered_comains+1
          else
            log.write( key + "  NOT found\n" )
          end
        end
        log.write( @count_covered_comains.to_s + "  covered domain queries were found/n" )
      end
  

  #LIST OF COVERED DOMAINS
  @covered_domans.each do |key, value|
    log.write( value.to_s + "\t" + key + "\n")
  end

log.write( "\n\nAnalysis of Intelius Electronic Logs for October, 2008\n-------------------------------------------------------\n")
log.write( "Records analyzed\t\t\t\t\t\t" +                     @lines.to_s + "\n\n")
log.write( "Records abandoned\t\t\t\t\t\t" +                    @count_repeated_IPs.to_s + "\n")
log.write( "Queries from qualified domains\t\t\t\t\t" +         @count_covered_comains.to_s + "\n")
log.write( "Queries from non-qualified domains\t\t\t\t" +       @count_not_covered_comains.to_s + "\n")
log.write( "Identified domains\t\t\t\t\t\t" +                  (@count_covered_comains + @count_not_covered_comains).to_s + "\n\n")
log.write( "Queries originated by bots and crawlers\t\t\t\t" +  @bots.to_s + "\n")
log.write( "Queries from qualified domains but originated by bots, crawlers\t" + @count_covered_and_bot.to_s + "\n\n")
log.write( "Total valid queries net of exclusions\t\t\t\t" +    (@count_covered_comains - @count_covered_and_bot).to_s + "\n\n")
log.write( "\n" + "%.3f" %                                      (completed_at - started_at).to_f + "\ttotal seconds to process QRY_FILE\n")
log.write( "%.3f" %                                             (@lines/(completed_at - started_at)).to_f + "\taverage records per second.\n" )

log.write( "test: " + test.to_s + "\n" )
log.write("__END__")
log.close

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

