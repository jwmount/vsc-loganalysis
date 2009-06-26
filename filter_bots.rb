# #!/usr/local/bin/ruby
#                    
#filter_bots.rb
require 'QClass.rb'
# Bot list from Intelius, downcased for case insensitivity
BOT_TOKENS = %w[ '' bot mediapartners-google inktomi slurp turnitin ask.com yahoo transcoder hotjobs voyager lwp-trivial mail.ru teoma 
               crawler findlinks twiceler ia_archiver-web nutchcvs wwwster spider sbider winhttprequest rpt-httpclient ichiro cfnetwork nagios 
               lwp::simple libwww python-urllib wget ]
VAC_bot_tokens = %w[ nil bot crawl seek scan search dig agent get spider scooter lint libwww loader mechanic curl link catch fly ]
class Qry < QClass  
  def initialize( file_in, out_file, limit)
    super( file_in, out_file, limit)
    @isbot = false
    filter
  end

  def filter
  # READ LOOP
    File.open( file_in, modestring = "r") do |f|
      f.each($/) do |line|
#        next if line =~ /^#|^=/  or line =~ /^$/  #skip comment and blank lines
        limit?
        progress?
        @isbot = false
        fields = line.split("\t")
        next if fields.length < UA_ID
        fields[UA_ID].downcase!
#fields[UA-id].casecmp(string)
        BOT_TOKENS.each do |b| 
          if fields[UA_ID].match(b)
            @bots = (@bots ||= 0 ) + 1
            @isbot = true
          end
        end
        write(line) unless @isbot
      end #read block    
    end #file block

  wrap_up("\nBOTS\t\t\t\t\t\t\t\t" + @bots.to_s  + "\n\n")
  end
end

Qry.new( (ARGV[0] ||= "qry_file.txt"), (ARGV[1] ||= "qry_file_out.txt"), (ARGV[2] ||= 100000000) )
