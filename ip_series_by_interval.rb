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

#IO.foreach("yb-searches-october02.txt") do |qry| 
IO.foreach("/Volumes/Webaudits/Intelius/OctoberInteliusWebRequests.txt") do |qry|
  @total_queries = @total_queries + 1
  @queryField = qry.split

# this stanza under development, appears that records are NOT in chronological order!
# in this case, we must tabulate into day/hour intervals to look at queries per hour.
  t = @queryField[1]
  hh = t[0,2]
  if hh != @current_hh
    @current_hh = hh
  end
  
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
    if qry.include? "crawl"
      @crawl = @crawl +1
      if @crawl < 11
        puts @total_queries.to_s +  ' ' + @crawl.to_s + ' ' + qry
      end
    end
  
  
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
  puts "* * * * * * Completed * * * * * *"
  
  completed_at = Time.new
  print "$isBot -- not a Bot: " + isNotBot.to_s + " is a bot: " + isBot.to_s, "\n"
  print "$clientIP -- Unique IP addresses: " + @Unique_IPs.to_s, "\n" 
  puts "'crawl' = " + @crawl.to_s

  puts "$queryType distribution"
  $qThash.each { |key,value|  print key, " = ", value, "\n" }

  print "Apparent bots based on time: " + @bots.to_s, "\n" 
  puts 'Total searches = ' + @total_queries.to_s
  secs = completed_at - started_at
  puts 'Completed in: '  "%.6f" % (completed_at - started_at).to_f + ' seconds.'
  print "Average of: " + "%.6f" % (@total_queries/(completed_at - started_at)).to_f + ' records per second.'