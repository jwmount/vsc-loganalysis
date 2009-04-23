#Unique (randomized at least) pet identifier
#NOT UUID compliant, not globally and chronologically unique
#map describes stanzas, can have any number of these
def rand_hex_3(l)
  "%0#{l}x" % rand(1 << l*4)
end

def rand_uuid
#  [8,4,4,4,12,24].map {|n| rand_hex_3(n)}.join('-')
  [8].map {|n| rand_hex_3(n)}.join('-').upcase
end


puts rand_uuid
