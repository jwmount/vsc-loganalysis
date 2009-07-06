# #!/usr/local/bin/ruby
#                    
#filter_bots.rb
#(c) Copyright 2009 VenueSoftware Corp. All Rights Reserved.
require 'QClass.rb'
# Bot list from Intelius, downcased for case insensitivity
BOT_TOKENS = %w[ bot mediapartners-google inktomi slurp turnitin ask.com yahoo transcoder hotjobs voyager lwp-trivial mail.ru teoma 
               crawler findlinks twiceler ia_archiver-web nutchcvs wwwster spider sbider winhttprequest rpt-httpclient ichiro cfnetwork nagios 
               lwp::simple libwww python-urllib wget ]
VAC_bot_tokens = %w[ nil bot crawl seek scan search dig agent get spider scooter lint libwww loader mechanic curl link catch fly ]
class Qry < QClass  
  def initialize( file_in, out_file, limit)
    super( file_in, out_file, limit)
    @bots = 0
    @isbot = false
    filter
  end

  def filter
  # READ LOOP
    File.open( file_in, modestring = "r") do |f|
      f.each($/) do |line|
        next if line =~ /^#|^=/  or line =~ /^$/  #skip comment and blank lines
        limit?
        progress?
        fields = line.split("\t")
        if fields[UA_ID].length == 0
          @bots += 1
          next
        end
        next if fields.length < UA_ID
        fields[UA_ID].downcase!
        @isbot = false
        BOT_TOKENS.each do |b| 
          if fields[UA_ID].include?(b)
            @bots += 1
            @isbot = true 
          end
          break if @isbot
        end
      write(line) unless @isbot
      end #read block    
    end #file block

  wrap_up("\nBOTS\t\t\t\t\t\t\t\t" + @bots.to_s  + "\n\n")
  end

end

Qry.new( (ARGV[0] ||= "qry_file.txt"), (ARGV[1] ||= "qry_file_out.txt"), (ARGV[2] ||= 100000000) )
