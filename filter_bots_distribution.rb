# #!/usr/local/bin/ruby
#                    
require 'QClass.rb'
# Bot list from Intelius, downcased for case insensitivity

class Qry < QClass  
  BOT_DISTRIBUTION =  true
  BOT_TOKENS = %w[ '' bot mediapartners-google inktomi slurp turnitin ask.com yahoo transcoder hotjobs voyager lwp-trivial mail.ru teoma 
                 crawler findlinks twiceler ia_archiver-web nutchcvs wwwster spider sbider winhttprequest rpt-httpclient ichiro cfnetwork nagios 
                 lwp::simple libwww python-urllib wget ]
  VAC_BOT_TOKENS = %w[ nil bot crawl seek scan search dig agent get spider scooter lint libwww loader mechanic curl link catch fly ]
  def initialize( file_in, out_file, limit)
    super( file_in, out_file, limit)
    filter
  end

  def filter    
    @bot_hash = {}
    @isbot = false
    @bots = 0
    # READ LOOP
    File.open( file_in, modestring = "r") do |f|
      f.each($/) do |line|
        next if line =~ /^#|^=/  or line =~ /^$/  #skip comment and blank lines
        limit?
        progress?
        fields = line.split("\t")
        next if fields.length < UA_ID
        fields[UA_ID].downcase!
        @isbot = false
        BOT_TOKENS.each do |b| 
          if fields[UA_ID].match(b)
            @bots = (@bots ||= 0 ) + 1
            @isbot = true
            if !@bot_hash.has_key?(b)   #if not in hash yet, add it
              newbotH = {b=>1}
              @bot_hash.update(newbotH)
            else                                  #if is, increment value and next record
              @bot_hash[ b ] = @bot_hash.fetch( b ) + 1
            end
          end
          break if @isbot
        end
        write(line) unless @isbot
      end #read block    
    end #file block

   # BOT_DISTRIBUTION
  log( "\tBot frequency distribution follows:\n\n" )
  @bot_hash.each do |key,value|
    @total = ( @total ||= 0 ) + value
    log( "  " + value.to_s + "\t\t\t\t" + key + "\n")
    end
  log( "__________________________\n" + @total.to_s + "\t\t\tTotal bots in distribution")

  wrap_up("\nBOTS\t\t\t\t\t\t\t\t" + @bots.to_s  + "\n\n" )
  end
end

Qry.new( (ARGV[0] ||= "qry_file.txt"), (ARGV[1] ||= "qry_file_out.txt"), (ARGV[2] ||= 100000000) )
