#                    
#analysis.rb -- Intelius log analyzer.
#opyright VenueSoftware Corp. 2008
# From J Caldwell email 1/2/09: records that are either outside the 50 states (QU or AB) or have unknown/erroneous codes (20, N?) should be excluded as valid searches
#To Do:
#1.  Extend the list of process types from 'bot' and 'crawl' to include others, e.g. 'slurp'


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
#QRY_FILE = "Oct08_Extract_10.txt"  #development testing
QRY_FILE = "Oct08_Extract_20000.txt" #development testing
#QRY_FILE = "yb-searches-October.txt" #Production, whole month
#QRY_FILE = "E:/Webaudits/Intelius/OctoberInteliusWebRequests.txt"  #changes, for use on server

@diagnostics = true                   #NOTE:  switched off after 1000 queries, not constant
@DIAG_LIMIT = 1000                       
COUNT_BOTS = true
COUNT_UNIQUE_DNAMES = false          #NOTE:  slow, conducts reverse domain name lookups
DN_ID = 8
UA_ID = 10

@bot_hash = {} 
@bots = 0
@domains = {}
@count_unique_IPs = 0
@count_repeated_IPs = 0
@have_IP = "no"    
@lines = 0
@outcome = ""
@thisDN = ""
@fields = []
@included = false
@ss = ""
no_where = 0
out_of_bounds = 0
within_bounds = 0
@aZIP = 0
@aState = 0
started_at = Time.new
puts started_at
covered_domains = [
                  ["addresses.com", /addresses.com/, 0, 0], ["iaf.net", /iaf.net/, 0, 0], ["areaconnect.com", /areaconnect.com/, 0, 0],
                  ["yellow.com", /yellow.com/, 0, 0],["findlinks.com", /findlinks.com/,0, 0],
                  ["phonebook.com", /phonebook.com/, 0, 0],["electricyellow", /electricyellow/, 0, 0],["whitepage.net", /whitepage/, 0, 0],
                  ["pumpkinpages.com", /pumpkinpages.com/, 0, 0],["uscity.net", /uscity.net/, 0, 0],
                  ["numberway.com", /numberway.com/, 0, 0],["reversephonedirectory.com", /reversephonedirectory/, 0, 0],["oregon.com", /oregon.com/, 0, 0],
                  ["wnd.com", /wnd.com/, 0, 0],["zabasearch.com", /zabasearch.com/, 0, 0]
                  ]
bot_tokens = [/bot/, /crawl/]
geo_filters = [/&where=/,/\d[5]+/]
@states = ["AK", "AZ", "AL","AR", "CA","CO", "CT","DE","FL","GA","HI","ID", "IL",  "il",  "IN","IA","KS","KY","LA","ME","MD","MA",
        "MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX",
        "UT","VT","VA","WA","WV","WI","wi","WY"]


log = File.open("log.txt", "w") 
if @diagnostics 
  log.write( "File: " + QRY_FILE)
  log.write( "File size: " + File.stat(QRY_FILE).size.to_s + " bytes\n")
  log.write( "diagnostics ON with DIAG_LIMIT = " + @DIAG_LIMIT.to_s + "\n")
  log.write( "DN_ID is: " + DN_ID.to_s + " UA_ID is: " + UA_ID.to_s  )
  log.write( "Began at: " + Time.now.to_s + "\n")
else
  puts "File: " + QRY_FILE
  puts "File size: " + File.stat(QRY_FILE).size.to_s + " bytes\n"
  puts "diagnostics are OFF\n"
  puts "DN_ID is: " + DN_ID.to_s + " UA_ID is: " + UA_ID.to_s
  puts "Began at: " + Time.now.to_s + "\n"
end


#
#READ LOOP
#
File.open(QRY_FILE, modestring = "r") do |f|
  f.each($/) do |line|  
  @lines = @lines + 1
  @fields = line.split("\t")        
  @diagnostics = false if @lines > @DIAG_LIMIT 
  @outcome = @lines.to_s + "\t" + @fields[6].to_s + "\t" if @diagnostics
  
  #  ClientIP addr is not from a covered domain.  
  # Take inventory of queries from unique IP addresses 
  # Count first occurance in a series only, but CONSIDER searches might not be same so we undercount unique searches this way
    if @have_IP == @fields[6].to_s
      @count_repeated_IPs += 1
      @outcome << "Repeated (skipped).\t"  if @diagnostics
      next 
    else
      @have_IP = @fields[6].to_s
      @count_unique_IPs += 1
      @outcome << "New  " if @diagnostics
    end
  #
  #Covered in list and bot determination
  #
  @included = false
  covered_domains.each do |d|
    if d[1].match(line)
      @included = true
      d[2] += 1
      bot_tokens.each do |b|
        if @fields[UA_ID].match(b)
          d[3] += 1
          @bots += 1
          @outcome << "\t__BOT__" + @fields[UA_ID] if @diagnostics
          if !@bot_hash.has_key?(@fields[UA_ID])   #if not in hash yet, add it
            newbotH = {@fields[UA_ID]=>1}
            @bot_hash.update(newbotH)
          else                                  #if is, increment value and next record
            @bot_hash[ @fields[UA_ID] ] = @bot_hash.fetch( @fields[UA_ID] ) + 1
          end
          next
        end
        next
      end
    end
  end
  
  #
  #FILTERS
  #
  #Filter out by geographic target of query 
  #
  #&where=green+bay+%2C+wi%2C  or &where=94965 are acceptable
  if !geo_filters[0].match(@fields[14])
    no_where += 1
#    next
  end
  
  #there is a &where clause, so save $' and point to state or zip code
  s = $'
  @outcome << "\ttarget location:\t" + s.to_s if @diagnostics
  ss = s.to_s.split("%2C+")
  ss = ss.to_s.split("&")

  #test for state code
  @aState = false
  state = ss[0].to_s.slice(-2,2)
  if @states.index(state)
    @aState = true
  else
    @aState = false
  end
  
  #not a state, maybe a zip code?
  @aZIP = false
  if @aState == false
    #test for zip code
    if ss.to_s.to_i != 0
      zip = ss[0].slice(0,5)
      @aZIP = true
    end
  end
  
  @outcome << @aState.to_s + "\t" + @aZIP.to_s if @diagnostics

  #if it's neither aState nor aZIP then skip it    
  if @aState 
    @outcome << "\t__COUNTED__\n" if @diagnostics
  then if @aZIP
    @outcome << "\t__COUNTED__\n"  if @diagnostics    
  else
    @outcome << "\t__OUT OF BOUNDS, SKIPPED__\t" if @diagnostics
    out_of_bounds += 1
  end
    


  log.write( @outcome + "\n") if @diagnostics
#end of read block    
end
#end of file block
end 


#Record the results in file f
  completed_at = Time.new
  
  log.write("\n\nCompleted: " + `date` + "\n") 
  log.write( @lines.to_s + " queries (records) in QRY_FILE \n\n" ) 

  # COUNT_BOTS
    if COUNT_BOTS
        log.write( "\nRobot and Crawler counts\n-------------------------\n")
        log.write( @bot_hash.length.to_s + "\tdistinct bots and crawlers were identified in QRY_FILE.\n\n")
        log.write( "\tFrequency distribution as follows:\n\n" )
        @bot_hash.each do |key,value|
          log.write( "  " + value.to_s + "\t" + key + "\n")
        end
        log.write( @bots.to_s + "\tTotal bots and crawlers identified.\n" )
    end

  log.write("\n\n")
  log.write( "Unique IP addresses\n---------------------\n(based on change in IP in sequence; only first one counted)\n\n")
  log.write( "\t" + @count_unique_IPs.to_s + "\tunique IPs\n" )
  log.write( "\t" + @count_repeated_IPs.to_s + "\tnon unique IP addresses (skipped)\n" )
  log.write( "\t" + (@count_unique_IPs + @count_repeated_IPs).to_s + "\ttotal\n")
 
  log.write("\n\n")
  log.write( "Domain Name List frequency analysis\n___________________________________\n\n")
  log.write( "\tDomain Name\t"+"In list".rjust(31)+"\t\tRejected*\ttotal\n")
  log.write( "\t___________\t"+"_______".rjust(31)+"\t\t_______\t\t_____\n")
  @totalInList = 0
  covered_domains.each do |dom|
    log.write "\t"  + dom[0].ljust(24) + "\t\t" + dom[2].to_s + "\t\t" + dom[3].to_s  + "\t\t" + (dom[2].to_i+dom[3].to_i).to_s + "\n"
    @totalInList += dom[2] += dom[3]
  end
  log.write "\n\tTotal\t\t\t\t\t\t\t\t\t" + @totalInList.to_s + "\n"
  log.write( "\t*Rejected as bots\n")
 
  log.write( "\n")
  log.write( "Geographic exclusions -- targeted location outside of US and WDC*\n___________________________________________________________________\n\n")
  log.write( "\t" + no_where.to_s + "\tQueries excluded because no location for search\n")
  log.write( "\t" + out_of_bounds.to_s + "\tQueries excluded because search target not in US or Washington DC\n")
  log.write( "\t\t*Note:  Geographic exclusions deducted from all covered domains.\n\n")
 
log.write("__END__")
log.write( "\n" + "%.3f" %                                      (completed_at - started_at).to_f + "\ttotal seconds to process QRY_FILE\n")
log.write( "%.3f" %                                             (@lines/(completed_at - started_at)).to_f + "\taverage records per second.\n" )

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

