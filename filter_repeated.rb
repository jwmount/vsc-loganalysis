# #!/usr/local/bin/ruby
#                    
#filter_repeated.rb

require 'QClass.rb'
SESSION_LENGTH = 1200                   #1200 seconds or 20 minut
PURGE_LENGTH = SESSION_LENGTH / 2
STATUS_OK = "0"
STATUS_INVALID_SEARCH = "*"
STATUS_REPEAT_SEARCH = "2"
DIAGNOSTICS = false
class Qry < QClass  
  def initialize( file_in, file_out, limit)
    super( file_in, file_out, limit)
    @fields = []
    @hwm = 0
    @time = ""
    @what = ""
    @where = ""
    @purge = 0
    @value = 0
    @sessionID = ""
    @visit = ""
    @count_repeated = 0
    @visits_in_session = {}
    filter
  end
  def qry_time(f)
    dt = f[0].split("gz:")
    tm = dt[1].split(" ")
    d = dt[1].split("-")
    yr = d[0]
    mo = d[1]
    day = d[2]
    t = tm[1].split(":")
    hr = t[0]
    min = t[1]
    sec = t[2]
    Time.local( yr, mo, day, hr, min, sec )
  end
  def qry_visit(what,where,sessionID)
    what + where + sessionID
  end
  def filter
    #READ & filter LOOP  
    File.open(file_in, modestring = "r") do |f|
      f.each($/) do |line|
        next if line =~ /^#/ or line =~ /^=/ or line =~ /^$/  #skip comment and blank lines
        limit?
        progress?
        status = STATUS_OK
        @fields = line.split("\t") 
    
    # more info page based on QUERYTYPE More Info
      if @fields[5] == '3' 
        id = line.split("&id=")
        if param_is_blank(id[1])
          status = STATUS_INVALID_SEARCH
          milestone = "\nsearch by QUERYTYPE but &id= was blank"
        end
        @count_repeated += 1 
        next
      end
    
      # phone search based on SEARCHTYPE_BYPHONE
      if @fields[4] == '14'
        pn = line.split("&PN=")
        if param_is_blank( pn[1] )
          status = STATUS_INVALID_SEARCH
          milestone = "\nSEARCHTYPE_BYPHONE but &PN= was blank"
        end
        @count_repeated += 1
        next
      end

      if status == STATUS_OK
    
        # this is the fun part, it's an info query
        # have we seen this visit before?  If so, how long ago?
        # is query a repeat?    

        @sessionID = @fields[12]
        begin
          providerURL = @fields[14].split("&")
        rescue
          puts "NoMethodError at query: #{count_asString}\n#{count_asString}"
          log( "NoMethodError at query: #{count_asString}\n#{count_asString}")
          next
        end
        @what = providerURL[7] ||= nil
        @where = providerURL[8] ||= nil
        if @what.nil? || @where.nil?
          status = STATUS_INVALID_SEARCH
          @count_repeated += 1
          next
        end
    
      @visit = qry_visit(@what, @where, @sessionID)
      @time = qry_time(@fields)
     
      # is query repeated?  if yes, is @STATUS_REPEAT_SEARCH
      if @visits_in_session.has_value?(@visit)
        status = STATUS_REPEAT_SEARCH
        @hwm = @visits_in_session.length if @visits_in_session.length > @hwm
      else
        @visits_in_session.update(@time => @visit)
        puts "newIP added: " + @visits_in_session[@time] + "\tcount: " + @visits_in_session.length.to_s     if DIAGNOSTICS
      end
    
      # using purge to limit session trash collection lets the collection length vary
      # consider if this will cause the counts of STATUS_REPEATED to be higher than they should be.
      # Perhaps not given that a query sessionID will change after session_length seconds and so not be found.
      # remove any queries older than time (of this one minus session_length)
      @purge += 1
      if @purge >= PURGE_LENGTH
        @visits_in_session.delete_if { |k,v| (@time - SESSION_LENGTH ) > k }
        @purge = 0
      end      
    end
  
    puts "status: " + status + "\t" + @visit if DIAGNOSTICS
    if status == STATUS_OK
      write( line )
    else
      @count_repeated += 1
    end
    @milestone = "\n\t\t\t\thigh water mark: " + @hwm.to_s + "\t" + "current items in session: " + @visits_in_session.length.to_s 
    @milestone += "\n\t\t\t\t" + @visit + "\n"

    end #end of read block    
  end #end of file block
  wrap_up("\nREPEATED:\t\t\t\t\t\t\t\t" + @count_repeated.to_s  + "\n\n")
end
end
#Instantiate the Qry object, initialize it and run filter method.  
Qry.new( (ARGV[0] ||= "qry_file.txt"), (ARGV[1] ||= "qry_file_out.txt"), (ARGV[2] ||= 100000000) )


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
