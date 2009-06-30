# #!/usr/local/bin/ruby
#                    
#intelius_count.rb
# Function -- Filter out bots using string tokens.
#          -- Default uses Intelius' strings
#          -- Works with array of strings or array of expressions
require 'QClass.rb'
# Bot list from Intelius, downcased for case insensitivity
BOT_TOKENS = %w[ // bot mediapartners-google inktomi slurp turnitin ask.com yahoo transcoder hotjobs voyager lwp-trivial mail.ru teoma 
               crawler findlinks twiceler ia_archiver-web nutchcvs wwwster spider sbider winhttprequest rpt-httpclient ichiro cfnetwork nagios 
               lwp::simple libwww python-urllib wget ]
VAC_bot_tokens = %w[ /bot/ /crawl/ /seek/ /scan/ /search/ /dig/ /agent/ /get/ /spider/ /scooter/ /lint/ /libwww/ /loader/ /mechanic/ /curl/ /link/ /catch/ /fly/]
class Qry < QClass  
  def initialize( file_in, out_file, limit)
    super( file_in, out_file, limit)
    filter
  end

  def filter
    @line = "www1.tuk.intelius.com-yp-searches.log.10052008.gz:2008-10-04 09:18:34	126	2444	107	12	2	74.37.41.100	0	webcrawler.intelius.com/yp_results.php?ReportType=44&provider=107&qc=Long+Creek&qs=IL
    	Mediapartners-Google	www148e79741823fa	www148e7974182bc9		http://api.yellowbook.com/yb_rest/GetListings.ashx?version=1.4&clientIp=74.37.41.100&browserAgent=Mozilla%2F4.0+%28compatible%3B+MSIE+7.0%3B+Windows+NT+6.0%3B+SLCC1%3B+.NET+CLR+2.0.50727%3B+Media+Center+PC+5.0%3B+.NET+CLR+3.0.04506%29&visitorId=www148e79741823fa&sessionId=www148e7974182bc9&serving=all&geoExpand=yes&what=&where=Long+Creek%2C+IL&type=byName&pageNumber=1&pageSize=10&sort=relevance"
    
        fields = @line.split("\t")
        BOT_TOKENS.find do |b| 
          if fields[9].downcase.match(b)
            @bots = (@bots ||= 0 ) + 1
            write(@line)
          end
        end

  wrap_up("\nBOTS\t\t\t\t\t\t\t\t" + @bots.to_s  + "\n\n")
  end
end

Qry.new( (ARGV[0] ||= "qry_file.txt"), (ARGV[1] ||= "qry_file_out.txt"), (ARGV[2] ||= 100000000) )
