# #!/usr/local/bin/ruby
# 
#filter_where.rb
# Function --  Filter out queries by type
#          -- qry is STATUS_NOWHERE is a misnomer, use filter_isUS if actual location in US is of interest.
#          -- qry is STATUS_NOWHERE if SEARCHTYPE == 14 and the value for &PN= in ProviderURL is blank
#          -- qry is STATUS_NOWHERE if QUERYTYPE == 3 and the value for &id= in ProviderURL is blank.
#          -- qry is STATUS_NOWHERE if SEARCHTYPE != 14 or QUERYTYPE != 3 and either &what= or &where= in ProviderURL is blank.

require 'QClass.rb'
STATUS_NO_WHERE = 3

class Qry < QClass  
  def initialize( file_in, out_file, limit)
    super( file_in, out_file, limit)
    @diagnostics = true
    @STATUS_OK = 0
    status = @STATUS_OK
    location = []
    fields = []
    @no_where = 0
    filter
  end
  def geo_filters
    geo_filters = [/&where=/,/&what/, /&id/]
  end

  def filter
    #READ LOOP
    File.open( file_in, modestring = "r") do |f|
    f.each($/) do |@line|
      limit?
      progress?
 
      fields = @line.split("\t")
      status = @STATUS_OK

    # more info page
    if fields[5] == '3' 
      id = @line.split("&id=")
      if param_is_blank(id[1])
        status = STATUS_NO_WHERE
      end
    end

    # phone search
    if fields[4] == '14'
      pn = @line.split("&PN=")
      if param_is_blank(pn[1])
        status = STATUS_NO_WHERE
      end
    end

    # what or where    
    if geo_filters[0].match(@line) || geo_filters[1].match(@line)
      location = @line.split("&what=")
      if param_is_blank(location[1])
        status = STATUS_NO_WHERE
      end
      location = @line.split("&where=")
      if param_is_blank(location[1])
        status = STATUS_NO_WHERE
      end
    end
    if status == @STATUS_OK
      write( @line )
    else
      @no_where += 1
    end
  
    milestone= "\n\t\t\t\tNO_WHERE: " +@no_where.to_s + " queries found." 
    end #end of read block    
  end #end of file block
  wrap_up( "NO_WHERE:\t\t\t\t\t" + @no_where.to_s)

end
end

Qry.new( (ARGV[0] ||= "qry_file.txt"), (ARGV[1] ||= "qry_file_out.txt"), (ARGV[2] ||= 100000000) )

#Sandeep's logic for STATUS_NOWHERE:
#-------------------------------------
 
#if(QUERYTYPE == 3) //more info page
#{
#  If(id_parameter_in_providerURL_is_blank)
#    status = STATUS_NOWHERE;
#}
#elseIf(SEARCHTYPE == 14) //phone search
#{
#  If(PN_parameter_in_providerURL_is_blank)
#      Status = STATUS_NOWHERE;
#}
#Elseif(what_parameter_in_providerURL_is_blank OR where_parameter_in_providerURL_is_blank)
#  Status = STATUS_NOWHERE;

#Record the results in file f

#END


