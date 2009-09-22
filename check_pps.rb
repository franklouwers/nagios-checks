#!/usr/bin/env ruby
require 'rubygems'
require 'memcached'
require 'snmp'



def usage
  puts "#{$0} host [community [warn_at [critical_at]]]"
  puts "  community: defaults to public"
  puts "  warn_at: defaults to 10000"
  puts "  warn_at: defaults to 30000"
  exit(0)
end

def validate_options
  if $host.nil?
    usage
  end

  if $community.nil?
    $community = "public"
  end

  if $warn_at.nil?
    $warn_at = 10000
  else
    $warn_at = $warn_at.to_i
    usage unless $warn_at > 0
  end

  if $critical_at.nil?
     $critical_at = 10000
   else
     $critical_at = $critical_at.to_i
     usage unless $critical_at > 0
   end

end

$cache = Memcached.new("localhost:11211")

$host = ARGV[0]
$community = ARGV[1]
$warn_at = ARGV[2]
$critical_at = ARGV[3]

validate_options

puts $host
puts $community
puts $warn_at
puts $critical_at
    

crit = []
warn = []

# TODO: SNMP::RequestTimeout opvangen
# TODO: SocketError (bv als geen correcte hostname)
SNMP::Manager.open(:Host => $host, :Community => $community) do |snmp|
  snmp.walk(["ifOutUcastPkts","ifInUcastPkts","ifDescr","ifAlias","ifIndex","ifOutNUcastPkts","ifInNUcastPkts"]) do |outpps, inpps, desc, ali, index,outbpps,inbpps|

    now = Time.now.to_i

    #cache proberen ophalen. Dit gooit een NotFound als object niet bestaat
    begin
      prevout = $cache.get "#{$host}-#{index.value}-out"
      previn = $cache.get "#{$host}-#{index.value}-in"
      prevbout = $cache.get "#{$host}-#{index.value}-bout"
      prevbin = $cache.get "#{$host}-#{index.value}-bin"
      prevtijd = $cache.get "#{$host}-#{index.value}-time"
      
      # TODO: opletten: overflow? TODO - 32bit integers
      diffin = (inpps.value.to_i - previn).to_f
      diffout = (outpps.value.to_i - prevout).to_f
      diffbin = (inbpps.value.to_i - prevbin).to_f
      diffbout = (outbpps.value.to_i - prevbout).to_f
      difftime = (now - prevtijd).to_f
      avginpps = diffin / difftime
      avgoutpps = diffout / difftime
      avgbinpps = diffbin / difftime
      avgboutpps = diffbout / difftime
      
#      puts "#{desc.value}: #{avginpps} / #{avgoutpps} (#{previn} -> #{inpps.value.to_i} - #{prevout} -> #{outpps.value.to_i})"
      

      descriptions = {"avginpps" => "In PPS", "avgoutpps" => "Out PPS","avgbinpps" => "InB PPS","avgboutpps" => "OutB PPS" }

      descriptions.each do |paar|
        pps = eval(paar[0])
        next if not pps.finite?
        pps = pps.to_i
        if pps > $critical_at
          #meer dan hoogste limiet: bewaren bij de criticals
          crit << "#{paar[1]} #{desc.value}: #{pps}"
          #puts "XXX CRIT: #{paar[1]} #{desc.value} (#{ali.value}): #{pps}"
        elsif pps > $warn_at  	   
          #meer dan tweede limiet: bewaren bij de warnings
          warn << "#{paar[1]} #{desc.value}: #{pps}"
          #puts "XXX WARNING: #{paar[1]} #{desc.value} (#{ali.value}): #{pps}"
        end
      end


    rescue Memcached::NotFound #geen memcache waarde gevonden, weinig zinvol iets te doen

    ensure
      $cache.set "#{$host}-#{index.value}-out", outpps.value
      $cache.set "#{$host}-#{index.value}-in", inpps.value
      $cache.set "#{$host}-#{index.value}-bout", outbpps.value
      $cache.set "#{$host}-#{index.value}-bin", inbpps.value
      $cache.set "#{$host}-#{index.value}-time", now
    end
  end
end

output = ""
#nu kijken welke crit en warn zijn. Eerst crit outputten
if not crit.empty?
  output += "CRITICAL "
  output += crit.join('-')
  output += " "
end
if not warn.empty?
  output += "WARNING "
  output += warn.join('-')
end
if output.empty?
  output = "OK"
end
puts output