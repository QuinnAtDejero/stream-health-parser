=begin
Stream Health Parser
- Get file
- Create file handler
- Pass it to the StreamHealthParser object
=end
require_relative 'StreamHealthParser'
require_relative 'LiveStat'

messages_on = false

filename = ARGV.first

if filename == nil
	print "File name: "
	filename = gets.chomp
end

if !File.exists? filename
	puts "Sorry, the file could not be opened or found. Please make sure it exists. Have a great day!"
	exit
end

file = File.open(filename, "r")
stream = StreamHealthParser.new(file)
puts "Stream health: #{stream.overall_health}"

if messages_on
	puts "\n"
	puts "Frame loss metric: #{stream.frame_lost_metric}"
	puts "Frame size change metric: #{stream.frame_size_change_metric}"
	puts "Frame size metric: #{stream.frame_size_metric}"
end

puts "\n"