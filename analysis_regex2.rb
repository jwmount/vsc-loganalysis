  # #!/usr/local/bin/ruby
#                    
#analysis.rb -- Intelius log analyzer.
puts '(c) Copyright 2009 VenueSoftware Corp. All Rights Reserved. '
# From J Caldwell email 1/2/09: records that are either outside the 50 states (QU or AB) or have unknown/erroneous codes (20, N?) should be excluded as valid searches

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

require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    options[:verbose] = v
  end
  opts.on("-d", "--[no-]diagnostics", "Show diagnostics") do |d|
    options[:diagnostics] = d
  end
end.parse!



QRY_FILE = "Oct08_Extract_20000.txt" #development testing
#QRY_FILE = "yb-searches-October.txt" #Production, whole month
#QRY_FILE = "E:/Webaudits/Intelius/OctoberInteliusWebRequests.txt"  #changes, for use on server

WRITE_STATUS_FILE = true              #NOTE:  will not write to output if COLLECT_UNIQUE_DOMAIN_NAMES is true
@diagnostics = true                   #NOTE:  switched off after 1000 queries, not constant
@DIAG_LIMIT = 1000                
COUNT_BOTS = true
COLLECT_UNIQUE_DOMAIN_NAMES = true          #NOTE:  slow, conducts reverse domain name lookups
DN_ID = 8
UA_ID = 10
STATUS_OK = "0"
STATUS_BOT = "1"
STATUS_REPEAT = "2"
STATUS_NOWHERE = "3"
STATUS_UNDETERMINED = "4"

@bots = 0
@count_unique_IPs = 0
@count_repeated_IPs = 0
@have_IP = "no"    
@lines = 0
@last_line = 0
@outcome = ""
@thisDN = ""
@fields = []
@status = [0,0,0,0,0]
@included = false
@ss = ""
@no_where = 0
@out_of_bounds = 0    #residual, unable to classify ; many or all are non US geo targets.
@aZIP = 0
@aState = 0
started_at = Time.new
puts started_at   
@bot_hash = {} 
@domains = {}
@covered_domains = [
                  ["addresses.com", /addresses.com/, 0, 0], ["iaf.net", /iaf.net/, 0, 0], ["areaconnect.com", /areaconnect.com/, 0, 0],
                  ["yellow.com", /yellow.com/, 0, 0],["findlinks.com", /findlinks.com/,0, 0],
                  ["phonebook.com", /phonebook.com/, 0, 0],["electricyellow", /electricyellow.com/, 0, 0],["whitepage.net", /whitepage.net/, 0, 0],
                  ["pumpkinpages.com", /pumpkinpages.com/, 0, 0],["uscity.net", /uscity.net/, 0, 0],
                  ["numberway.com", /numberway.com/, 0, 0],["reversephonedirectory.com", /reversephonedirectory/, 0, 0],["oregon.com", /oregon.com/, 0, 0],
                  ["wnd.com", /wnd.com/, 0, 0],["zabasearch.com", /zabasearch.com/, 0, 0]
                  ]
@bot_tokens = [/bot/, /crawl/, /seek/, /scan/, /search/, /dig/,/agent/,/get/,/spider/,/scooter/,/lint/,/libwww/,/loader/,/mechanic/,/curl/,/link/,/catch/,/fly/]
@geo_filters = [/&where=/,/[0-9]{5}/,/"%2C+"/]
@states = ["AK","ak", "AZ","az", "AL","al","AR","ar", "CA","ca","CO","co", "CT","ct","DE","de","FL","fl","GA","ga","HI","hi","ID","id", "IL","il", "IN","in","IA","ia","KS","ks","KY","ky","LA","la","ME","me","MD","md","MA","ma",
           "MI","mi","MN","mn","MS","ms","MO","mo","MT","mt","NE","ne","NV","nv","NH","nh","NJ","nj","NM","nm","NY","ny","NC","nc","ND","nd","OH","oh","OK","ok","OR","or","PA","pa","RI","ri","SC","sc","SD","sd","TN","tn","TX","tx",
           "UT","ut","VT","vt","VA","va","WA","wa","WV","wv","WI","wi","WY", "wy", "DC", "dc"]


@log = File.open("log.txt", "w") 
if @diagnostics 
  @log.write( "File: " + QRY_FILE)
  @log.write( "File size: " + File.stat(QRY_FILE).size.to_s + " bytes\n")
  @log.write( "diagnostics ON with DIAG_LIMIT = " + @DIAG_LIMIT.to_s + "\n")
  @log.write( "DN_ID is: " + DN_ID.to_s + " UA_ID is: " + UA_ID.to_s  )
  @log.write( "Began at: " + Time.now.to_s + "\n")
else
  puts "File: " + QRY_FILE
  puts "File size: " + File.stat(QRY_FILE).size.to_s + " bytes\n"
  puts "diagnostics are OFF\n"
  puts "DN_ID is: " + DN_ID.to_s + " UA_ID is: " + UA_ID.to_s
  puts "Began at: " + Time.now.to_s + "\n"
end

# Count first occurance in a series only, but CONSIDER searches might not be same so we undercount unique searches this way
def check_repeats(l)  
  repeat = false
  if @have_IP == @fields[6].to_s
    @count_repeated_IPs += 1
    @log.write( "\t __REPEATED__\n")  if @diagnostics
    status( STATUS_REPEAT, l )
    repeat = true
   else
    @have_IP = @fields[6].to_s
    @count_unique_IPs += 1
  end
  repeat
end

# check_bots -- count bots and accumulate bot distribution @bot_hash{}
def check_bots(l)
  aBot = false
  @bot_tokens.each do |b|
    if @fields[UA_ID].match(b)
      aBot = true
      @log.write("\t" + @fields[UA_ID] + "\t__BOT__\n")  if @diagnostics
      @bots += 1
      if !@bot_hash.has_key?(@fields[UA_ID])   #if not in hash yet, add it
        newbotH = {@fields[UA_ID]=>1}
        @bot_hash.update(newbotH)
      else                                  #if is, increment value and next record
        @bot_hash[ @fields[UA_ID] ] = @bot_hash.fetch( @fields[UA_ID] ) + 1
      end
    end
  end
  status( STATUS_BOT, l ) if aBot
  aBot
end


#&where=green+bay+%2C+wi%2C  or &where=94965 are acceptable
def check_where(l)
  if !@geo_filters[0].match(@fields[14])
    @no_where += 1
    @log.write("\t __NO WHERE__\n")    if @diagnostics
    status( STATUS_NOWHERE, l)
    true
  else
    false
  end
end

def check_zip(l)
  ss = @geo_filters[1].match(@fields[14])
  aZIP = false
  #test for zip code
  aZIP = true if ss
  @log.write( "\t" + ss.to_s + "\t__ZIP CODE__") if aZIP && @diagnostics
  status( STATUS_OK, l ) if aZIP
  aZIP
end

def check_state(l)
  aState = true
  s = @geo_filters[0].match(@fields[14])
  s = $'
  ss = s.to_s.split("%2C+")
  ss = ss.to_s.split("&")  
  #test for state code
  state = ss[0].to_s.slice(-2,2)  
  if !@states.index(state).nil?
    @log.write( "\t state: " + state.to_s + "\t__STATE IS US__\n") if  @diagnostics
  else
    @out_of_bounds += 1
    aState = false
    @log.write( "\t state: " + state.to_s + "\t__STATE NOT US__\n") if  @diagnostics
  end
  status( STATUS_OK, l) if aState 
  aState
end

def check_domain(l)
  listed = false
  @covered_domains.each do |d|
    if d[1].match(l)
      @log.write("\t" + @fields[DN_ID] + "\t" + d[0].to_s + "\t__COVERED__\n") if @diagnostics
      listed = true
      d[2] += 1
    end
  end
  status( STATUS_OK, l ) if listed
  listed
end

def progress_notice
  x = nil
  while !x
    Thread.new do
      sleep 10
      puts @lines.to_s + "\t" + Time.new.to_s + "\n"  
   end
 end
end

#collect/accumulate hash of unique present domain names and
#take frequency distribution
def collect_domains(l)
  return unless COLLECT_UNIQUE_DOMAIN_NAMES
  fields = l.split("\t")
  fields = fields[DN_ID].split(".")
  dn = ( fields[1].to_s + "." + fields[2].to_s )
  dom = {dn, 0}
  @domains.merge!(dom) {|k, o, n| o } 
  @domains[ dn ] = @domains.fetch( dn ) + 1
end

def status(s, l)
  return unless WRITE_STATUS_FILE
  if WRITE_STATUS_FILE && @lines == 34000000
    @o.close
    @o = File.open( "status_file2.txt", modestring = "w")
  end
  @o.write( s + "\t" + l)
  @status[s.to_i] += 1
  @last_line = @line
end

@o = File.open("status_file.txt", modestring = "w") if WRITE_STATUS_FILE

#READ LOOP
#
File.open(QRY_FILE, modestring = "r") do |f|
  f.each($/) do |line|  
    @lines += 1
    puts @lines.to_s + "\trecords @\t" + Time.new.to_s if @lines.modulo(1000000)  == 0
    @diagnostics = false if @lines > @DIAG_LIMIT 
    @log.write( @lines.to_s + "\t" + @fields[6].to_s + "\t") if @diagnostics
    @fields = line.split("\t")

#    collect_domains(line)
#    check_domain(line)
    next if check_repeats(line)
    next if check_bots(line)
    next if check_where(line)
    next if check_zip(line)
    next if check_state(line)
  
    status( STATUS_UNDETERMINED, line)   #should be zero!
  #end of read block    
  end
#end of file block
end 


#Record the results in file f
  completed_at = Time.new
  
  @log.write("\n\nCompleted: " + completed_at.to_s + "\n") 
  @log.write( @lines.to_s + " queries (records) in QRY_FILE \n\n" ) 

  # COLLECT_UNIQUE_DOMAIN_NAMES
  if COLLECT_UNIQUE_DOMAIN_NAMES
    sorted_domains = @domains.sort {|a,b| a[1] <=> b[1] }
    total = 0
    sorted_domains.each do |k, v|
      total += v.to_i
      @log.write( "\t" + v.to_s + "\t" + k.to_s + "\n")
    end
    @log.write( "\n\t" + total.to_s + "\tTotal\n")
  end
  # COUNT_BOTS
    if COUNT_BOTS
        @log.write( "\nRobot and Crawler counts\n-------------------------\n")
        @log.write( @bot_hash.length.to_s + "\tdistinct bots and crawlers were identified in QRY_FILE.\n\n")
        @log.write( "\tFrequency distribution as follows:\n\n" )
        @bot_hash.each do |key,value|
          @log.write( "  " + value.to_s + "\t" + key + "\n")
        end
        @log.write( @bots.to_s + "\tTotal bots and crawlers identified.\n" )
    end

  @log.write("\n\n")
  @log.write( "Unique IP addresses\n---------------------\n(based on change in IP in sequence; only first one counted)\n\n")
  @log.write( "\t" + (@count_unique_IPs + @count_repeated_IPs).to_s + "\ttotal\n")
  @log.write( "\t" + @count_repeated_IPs.to_s + "\tnon unique IP addresses (skipped)\n" )
  @log.write( "\t" + @count_unique_IPs.to_s + "\tunique IPs\n" )
 
  @log.write("\n\n")
  @log.write( "Domain Name List frequency analysis\n___________________________________\n\n")
  @log.write( "\tDomain Name\t"+"In list".rjust(31) + "\n")
  @log.write( "\t___________\t"+"_______".rjust(31) + "\n")
  @totalInList = 0
  @covered_domains.each do |dom|
    @log.write "\t"  + dom[0].ljust(24) + "\t\t" + dom[2].to_s +  "\n"
    @totalInList += dom[2]
  end
  @log.write( "\n\tTotal\t\t\t\t\t" + @totalInList.to_s + "\n")
  
  @log.write( "\n")
  @log.write( "Geographic exclusions -- targeted location outside of US and WDC*\n___________________________________________________________________\n\n")
  @log.write( "\t" + @no_where.to_s + "\tQueries excluded because no location for search\n")
  @out_of_bounds = @lines - @count_repeated_IPs - @totalInList - @bots - @no_where
  @log.write( "\t" + @out_of_bounds.to_s + "\tQueries excluded because search target not in US or Washington DC\n")
  @log.write( "\t\t*Note:  Geographic exclusions deducted regardless of domain in list or not.\n\n")

#Settings 
  @log.write( "Parameter settings and switches\n-------------------------------------\n")
  @log.write( "Input file name: \t\t" + QRY_FILE + "\n")
  @log.write( "Diagnostics set to: \t\t" + @diagnostics.to_s + "\n" )
  @log.write( "Diagnostics limit: \t\t" + @DIAG_LIMIT.to_s + "\n" )
  @log.write( "Count Bots:  \t\t\t" + COUNT_BOTS.to_s + "\n" )
  @log.write( "Collect unique domain names: \t" + COLLECT_UNIQUE_DOMAIN_NAMES.to_s + "\n" )
  @log.write( "Domain name index in record: \t" + DN_ID.to_s + "\n" )
  @log.write( "User agent index in record: \t" + UA_ID.to_s + "\n" )
  @log.write( "Write status file: \t\t" + WRITE_STATUS_FILE.to_s + "\n" )
  
  @log.write( "Status, OK: \t\t\t" + @status[0].to_s + "\n" )                                    if WRITE_STATUS_FILE
  @log.write( "Status, BOT: \t\t\t" + @status[1].to_s + "\n" )                                   if WRITE_STATUS_FILE
  @log.write( "Status, REPEAT: \t\t" + @status[2].to_s + "\n" )                                  if WRITE_STATUS_FILE
  @log.write( "Status, NOWHERE: \t\t" + @status[3].to_s + "\n" )                                 if WRITE_STATUS_FILE
  @log.write( "Status, UNDETERMINED: \t\t" + @status[4].to_s + "\n" )                            if WRITE_STATUS_FILE
  @log.write( "\t\t\t\t" + (@status[0]+@status[1]+@status[2]+@status[3]+@status[4]).to_s + "\n") if WRITE_STATUS_FILE


@log.write("__END__")
@log.write( "\n" + "%.3f" %                                      (completed_at - started_at).to_f + "\ttotal seconds to process QRY_FILE\n")
@log.write( "%.3f" %                                             (@lines/(completed_at - started_at)).to_f + "\taverage records per second.\n" )
@log.close

#
# Report the results recorded in log.txt
#  
puts "\n"
File.open("log.txt", "r") do |f|
  while line = f.gets
    puts line
  end
@o.close()  if WRITE_STATUS_FILE
#END
end

