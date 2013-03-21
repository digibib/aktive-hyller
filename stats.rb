#!/usr/bin/env ruby
# encoding: UTF-8

require "sqlite3"

unless ARGV.length == 2
  puts "Usage: stats.rb from-date to-date"
  puts "       dateformat: YYYY-mm-dd"
  exit
end

from_date, to_date = ARGV
constraint = "BETWEEN date('#{from_date}') AND date('#{to_date}')"
s = {}

db = SQLite3::Database.open "logs/stats.db"

# Number of sessions
s[:num] = db.get_first_value "select count(*) from sessions where date(start) "+constraint

# Session length: sum, avg, min, max
s[:sum], s[:avg], s[:min], s[:max] = db.get_first_row "select sum(length), avg(length), min(length), max(length) from (select ((strftime('%s', stop)-strftime('%s', start)))/60.0 AS length from sessions where date(start) #{constraint})"

# Omtalevisninger: sum, avg, max
s[:omtale_sum], s[:omtale_avg], s[:omtale_max] = db.get_first_row "select sum(omtale), avg(omtale), max(omtale) from sessions where date(start) " + constraint

# Antall besøk: rfid, flere, relaterte
s[:rfid], s[:flere], s[:relaterte] = db.get_first_row "select sum(rfid), avg(flere), max(relaterte) from sessions where date(start) " + constraint

s[:anbf_count], s[:anbf_avg] = db.get_first_row "select count(*), avg(antall) from omtaler where date(time) " + constraint
s[:null_treff] = db.get_first_value "select count(*) from omtaler where antall=0 and date(time) "+ constraint

puts "AKTIVE HYLLER: Statistikkrapport for perioden #{from_date} til #{to_date}"
puts "="*79
puts
puts "Sesjoner"
puts "----------------------------"
puts "  antall       : %d" % (s[:num] || 0)
puts "  lengde (sum) : %2.1f min." % (s[:sum] || 0)
puts "  lengde (avg) : %2.1f min." % (s[:avg] || 0)
puts "  lengde (min) : %2.1f min." % (s[:min] || 0)
puts "  lengde (max) : %2.1f min." % (s[:max] || 0)
puts
puts "Treff, antall"
puts "----------------------------"
puts "  omtale   : %d" % (s[:omtale_sum] || 0)
puts "  rifd     : %d" % (s[:rfid] || 0)
puts "  flere    : %d" % (s[:flere] || 0)
puts "  lignende : %d" % (s[:relaterte] || 0)
puts
puts "Omtalevisning"
puts "----------------------------"
puts "  avg pr. sesjon  : %d" % (s[:omtale_avg] || 0)
puts "  max pr. sesjon  : %d" % (s[:omtale_max] || 0)
puts
puts "Anbefalinger"
puts "----------------------------"
puts "  antall (avg)   : %.1f" % (s[:anbf_avg] ||0)
puts "  antall 0-treff : %d" % (s[:null_treff] ||0)
puts "  0-treff i %%    : %.1f" % (((s[:null_treff]/s[:anbf_count].to_f)*100) || 0)
puts
puts "Bøker uten anbefalinger"
puts "-"*79

stm = db.prepare "select distinct author, title, uri from omtaler where antall=0 and date(time) "+constraint
omtaler = stm.execute
omtaler.each do |row|
  puts "%s - \"%s\" - %s " % [row[0], row[1], row[2]]
end
stm.close if stm
