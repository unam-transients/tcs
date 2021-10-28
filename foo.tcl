puts "opening"
set host "192.168.100.28"
set port "200"

set channel [socket $host $port]
chan configure $channel -blocking false
chan configure $channel -buffering "line"
chan configure $channel -encoding "ascii"
#chan configure $channel -translation binary

puts "sending"
set command "GeneralStatus\n"

puts -nonewline $channel $command
flush $channel
#puts $channel $command

after 1000

puts "receiving"

set response [read $channel]
puts $response

