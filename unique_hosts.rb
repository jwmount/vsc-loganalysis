target_data_file = "yb-searches-october02.txt"
#target_data_file = "/Volumes/Webaudits/Intelius/OctoberInteliusWebRequests.txt" 
@total_queries = 0
@crawl = 
@qrytype_negative = 0
@queryType = Array(6)
$qThash = {}
isNotBot = 0
isBot = 0
@bots = 0
@Unique_IPs = 0
@current_ip = nil
@current_hh = '00'
started_at = Time.new
puts Time.now

IO.foreach(target_data_file) do |qry| 

  @queryField = qry.split
puts @queryField[9]
#
# Test - Total qry count
#
  @total_queries = @total_queries + 1
         
#
# Test - Unique Hosts
#

#
# Test - Exclusions for non-Intelius Websites
#
  #Need a list of Intelius IP addresses
#
# Test Suite - Exclusions of bots, spiders, crawlers and automated processes, devices
#              programs, algorithms or methodologies. 

#
# Covered Intelius IP Addresses
#
   @coveredIP_addresses = { "Addresses.com" => 0,                     #"64.94.125.138",
                            "iaf.net" => 0,                           #"64.94.125.136",
                            "Areaconnect.com" => 0,                   #"207.218.211.50",
                            "Yellow.com" => 0,                        #"72.5.62.135",
                            "FindLinks.com" => 0,                     #"72.5.62.138:",
                            "PhoneBook.com" => 0,                     #"76.74.159.103",
                            "ElectricYellow.com" => 0,                #"216.104.161.105",
                            "whitePage.net" => 0,                     #"64.94.125.137",
                            "PumpkinPages.com" => 0,                  #"68.178.232.100",
                            "UScity.net" => 0,                        #"208.111.25.9",
                            "NumberWay.com" => 0,                     #"64.85.165.61",
                            "ReversephoneDirectory.com" => 0,         #"64.94.125.153",
                            "Oregon.com" => 0,                        #"206.212.237.50",
                            "WND.com" => 0,                           #"70.85.95.100",
                            "ZabaSearch.com" => 0 }                   #"216.52.81.211" 

# $isBot distribution
  isNotBot = isNotBot + 1 if @queryField[8] == '0'
  isBot = isBot + 1 if @queryField[8] == '1'

# Get distribution of $queryType using $qThash
  if !$qThash.has_key?(@queryField[6])   #if not in hash yet, add it
    newqTh = {@queryField[6]=>1}
    $qThash.update(newqTh)
  else                                  #if is, increment value
    v = $qThash.fetch( @queryField[6] )
    $qThash[ @queryField[6] ]= v + 1
  end

#Count occurences of string "crawl"  about 15 seconds per day
#puts @queryField[11] + " " + @queryField[12] + @queryField[13]
#    if @queryField[11] = "Bot|bot|BOT|ROBOT|robot|Robot|crawl|CRAWL|Crawl +
#    bot|seek|scan|search|dig|agent|get|crawl|spider|scooter|lint|libwww|loader|mechanic|curl|link|catch|fly"
#      @crawl = @crawl +1
#      if @crawl < 11
#        puts @total_queries.to_s +  ' ' + @crawl.to_s + ' ' + qry
#      end
#    end
  markers = "Bot|bot|BOT|ROBOT|robot|Robot|crawl|CRAWL|Crawl +
                        seek|scan|search|dig|agent|get|crawl|spider|scooter|lint|libwww|loader|mechanic|curl|link|catch|fly +
                        speedy"
  @crawl = @crawl + 1 unless !markers[@queryField[11]]
  #puts @queryField[11]
  
#count runs from same IP address
#on changed address, record time, set as current address
#if not changed, and time_now - time < 2 seconds count as bot  
#  x = @queryField[1].each{|t| p t}
#  x = "'PST' 2008 'Oct' 2 " + x + "000"
#  t = Time.gm(x)
# interval is how long the time interval is, milliseconds
  interval = 2000  
  
  if @queryField[7] != @current_ip
    t0 = @queryField[1]
    h0 = t0[1,2]
    m0 = t0[4,2]
    s0 = t0[7,2]
    @time_start = Time.utc( 2000, "Oct", 2, h0,m0,s0) + interval
    @current_ip = @queryField[7]
  else     
    t = @queryField[1]
    hh = t[1,2]
    mm = t[4,2]
    ss = t[7,2]
    t=Time.utc( 2000, "Oct", 2, hh, mm, ss)    
    if ( t > @time_start )
      @bots = @bots + 1
    end
  end
end #end of read loop
#Show results
  puts ''
  puts "* * * * * * Completed * * * * * *"
  completed_at = Time.now
  puts Time.now
  
  print "$isBot -- not a Bot: " + isNotBot.to_s + " is a bot: " + isBot.to_s, "\n"
  print "$clientIP -- Unique IP addresses: " + @Unique_IPs.to_s, "\n" 
  puts "Filtered bots and crawlers: ' = " + @crawl.to_s

  puts "$queryType distribution"
  $qThash.each { |key,value|  print key, " = ", value, "\n" }

  print "Apparent bots based on time: " + @bots.to_s, "\n" 
  puts 'Total queries = ' + @total_queries.to_s
  secs = completed_at - started_at
  puts 'Completed in: '  "%.6f" % (completed_at - started_at).to_f + ' seconds.'
  print "Average of: " + "%.6f" % (@total_queries/(completed_at - started_at)).to_f + ' records per second.'  
  
  