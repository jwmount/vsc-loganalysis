# test

test_hash = {"1" => "one"}
test_hash.delete("1")

time = Time.now
newhash = {time => "whenever"}
test_hash.update(newhash)
whenever = time - 1400
test_hash.update(whenever => "whenever mius 1400")
add1200 = test_hash[whenever]
whenever = time - 1000
test_hash.update(whenever => "third_one")

test_hash.each do |k,v|
  puts k.to_s + "\t" + v
end
time = Time.now

puts 'then delete the old ones'
test_hash.delete_if {|k,v| (time - 1200) > k }  #if time k - 20 minutes is more recent, true, works

test_hash.each do |k,v|
  puts k.to_s + "\t" + v
end