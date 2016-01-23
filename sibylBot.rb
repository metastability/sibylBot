#! /usr/bin/env ruby
# decide, roll bot
# built using rirc

require 'rirc' # this line must be at the top of the file
require 'net/http'
require 'optparse'
require 'open-uri'
require 'json'
require 'date'

network = "irc.rizon.net"
port = 6697
pass = ""
nick = "sibylBot"
username = "sigma"
realname = "sibyl"
nickserv_pass = ""
channels = []
admins = ["themeta"]
use_ssl = true
use_pass = false
ign_list = []

class Waifu
	def initialize
		@waifu = "none"
		@urls = []
	end

	def setWaifu waifu
		@waifu = waifu
	end

	def addUrl url
		if not @urls.include? url then
			@urls.push(url)
		end
	end

	def rmUrl num
		@urls.delete_at(num.to_i - 1)
	end

	def getWaifu
		return @waifu
	end

	def getUrls
		return @urls
	end

	def getUrlsString
		r = ""
		i = 1
		@urls.each { |url| r.concat("#{i} #{url} ") }
		r = r[0..-2].to_s
		return r
	end
end

def loadWaifus

	if not File.exists?("./waifus")
		`touch ./waifus`
		return
	end

	lines = File.readlines("./waifus").map(&:chomp!)

	$waifus = {}
	$users = []

	lines.each do |line|
		tokens = line.split(" -- ")
		nick = tokens[0]
		waifu = tokens[1]
		if tokens[2].include? " - "
			urls = tokens[2].split(" - ")
		else
			urls = []
			urls.push(tokens[2])
		end

		temp = Waifu.new
		temp.setWaifu(waifu)
		urls.each { |url| temp.addUrl(url) }

		$users.push(nick)
		$waifus.store(nick, temp)
	end
end

def saveWaifus
	
	lines = []

	`rm -f ./waifus`

	$users.each do |nick|
		temp = $waifus[nick]
		waifu = temp.getWaifu
		urls = temp.getUrls

		if waifu == "none"
			next
		end

		if urls.length == 0
			urls.push "no urls"
		end

		line = "#{nick} -- #{waifu} -- " 
		# lines are formatted nick -- waifu -- url1 - url2 ...
		urls.each { |url| line.concat("#{url} - ") }
		line = line[0..-4].to_s
		lines.push(line)
	end

	File.open("./waifus", 'w') do |fw|
		lines.each do |line|
			puts line
			fw.puts line
		end
	end
end

def loadWeather

	if not File.exists?("./weather")
		`touch ./weather`
		return
	end

	weatherUsers = File.readlines("./weather").map(&:chomp!)

	weatherUsers.each do |user|
		nick = user.split(":")[0].to_s
		areaCode = user.split(":")[1].to_s

		if areaCode =~ /\[(\S+ ?)+\]/
			areaCode = areaCode[1..-2]
			tokens = areaCode.split(", ")
			tokens[0] = tokens[0].to_s[1..-2].to_s
			tokens[1] = tokens[1].to_s[1..-2].to_s
			city = tokens[0]
			state = tokens[1]
			areaCode = [city, state]
		end

		$usersW.push(nick)
		$weather.store(nick, areaCode)
	end
end

def saveWeather

	`rm -f ./weather`

	File.open("./weather", 'w') do |fw|
		$usersW.each do |user|
			fw.puts "#{user}:#{$weather[user].to_s}"
		end
	end
end

def weatherc(c)
	wc = Hash.new

	wc = {200 => "thunderstorm with light rain", 201 => "thunderstorm with rain", 202 => "thunderstorm with heavy rain", 210 => "light thunderstorm", 211 => "thunderstorm", 212 => "heavy thunderstorm", 221 => "ragged thunderstorm", 230 => "thunderstorm with light drizzle", 231 => "thunderstorm with drizzle", 231 => "thunderstorm with heavy drizzle", 300 => "light intensity drizzle", 301 => "drizzle", 302 => "heavy intensity drizzle", 310 => "light intensity drizzle rain", 311 => "drizzle rain", 312 => "heavy intensity drizzle rain", 313 => "shower rain and drizzle", 314 => "heavy shower rain and drizzle", 321 => "shower drizzle", 500 => "light rain", 501 => "moderate rain", 502 => "heavy intensity rain", 503 => "very heavy rain", 504 => "extreme rain", 511 => "freezing rain", 520 => "light intensity shower rain", 521 => "shower rain", 522 => "heavy intensity shower rain", 531 => "ragged shower rain", 600 => "light snow", 601 => "snow", 602 => "heavy snow", 611 => "sleet", 612 => "shower sleet", 615 => "light rain and snow", 616 => "rain and snow", 620 => "light shower snow", 621 => "shower snow", 622 => "heavy shower snow",701 => "mist", 711 => "smoke", 721 => "haze", 731 => "sand, dust. whirls", 741 => "fog", 751 => "sand", 761 => "dust", 762 => "volcanic ash", 771 => "squalls", 781 => "tornado", 800 => "clear sky", 801 => "few clouds", 802 => "scattered clouds", 803 => "broken clouds", 804 => "overcast clouds", 900 => "tornado", 901 => "tropical storm", 902 => "hurricane", 903 => "cold", 904 => "hot", 905 => "windy", 906 => "hail", 951 => "calm", 952 => "light breeze", 953 => "gentle breeze", 954 => "moderate breeze", 955 => "fresh breeze", 956 => "strong breeze", 957 => "high wind, near gale", 958 => "gale", 959 => "severe gale", 960 => "storm", 961 => "violent storm", 962 => "hurricane"}

	return wc.fetch(c.to_i).to_s
end

def getWeather_CS city, state
	areaCode = "#{city},#{state}"
	url = "http://api.openweathermap.org/data/2.5/weather?q=#{areaCode}&mode=json&units=imperial&APPID=a339079c4704cf90448be7e467027c02"
	url_m = "http://api.openweathermap.org/data/2.5/weather?q=#{areaCode}&mode=json&units=metric&APPID=a339079c4704cf90448be7e467027c02"

	return getWeather(url, url_m, areaCode)
end

def getWeather_aC areaCode
	url = "http://api.openweathermap.org/data/2.5/weather?zip=#{areaCode},us&mode=json&units=imperial&APPID=a339079c4704cf90448be7e467027c02"
	url_m = "http://api.openweathermap.org/data/2.5/weather?zip=#{areaCode},us&mode=json&units=metric&APPID=a339079c4704cf90448be7e467027c02"

	return getWeather(url, url_m, areaCode)
end

def getWeather url, url_m, area_code

		@r_w = ""
		@ac = area_code

		begin
			@contents = open(url).read
		rescue => a
			return "#{@ac}\'s weather cannot be located"
		end

		begin
			@contents_m = open(url_m).read
		rescue => a
			return "#{@ac}\'s weather cannot be located"
		end

		contents = open(url).read
		contents_m = open(url_m).read
		parsed_json = JSON.parse(contents)
		parsed_json_m = JSON.parse(contents_m)
		if parsed_json['main'].nil?
			@r_w = "#{@ac}\'s weather cannot be located"
		elsif weather_in_f = (parsed_json['main']['temp']).to_i
			begin
				weather_in_c = (parsed_json_m['main']['temp']).to_i
			rescue NoMethodError => e
				return "#{@ac}\'s weather cannot be located"
			end
			humidity = parsed_json['main']['humidity']
			weathercode = weatherc("#{parsed_json['weather'][0]['id']}")
			@r_w.concat("Weather for \x0304#{@ac.to_s}\x03 #{weathercode} at \x0302#{weather_in_f}°F\x03 or \x0302#{weather_in_c}°C\x03 and winds at \x0311#{parsed_json['wind']['speed']} mph\x03")
		end

		return @r_w
end

def saveUnderwear
	File.open("./underwear", 'w') do |fw|
		$usersU.each do |user|
			temp_nick = user
			temp_underwear = $underwear[user]
			l = "#{temp_nick}:$temp_underwear"
			fw.puts l
		end
	end
end

def loadUnderwear
	lines = File.readlines("./underwear").map(&:chomp!)
	lines.each do |lineI|
		temp_nick = lineI.split(":")[0].to_s
		temp_underwear = lineI.split(":")[1].to_s
		$usersU.push(temp_nick)
		$underwear.store(temp_nick, temp_underwear)
	end
end

$users = []
$waifus = {}

$usersW = []
$weather = {}

$usersU = []
$underwear = {}

pluginmgr = nil

bot = IRCBot.new(network, port, nick, username, realname)
bot.set_admins(admins)

commands = Commands_manager.new

commands.on /^,leave$/ do |ircbot, msg, pluginmgr|

	if msg.nick == admins[0]
		saveWaifus
		saveWeather
		saveUnderwear
		abort
	end
end

bot.on :message do |msg|
    commands.check_cmds(bot, msg, pluginmgr)
end

=begin
# decide
bot.on :message do |msg|
	case msg.message
	when /^`decide (\S+, ?)+(\S+)/ then
		tokens = msg.message[9..-1].split(",")
		i = rand(tokens.length - 1)
		bot.privmsg(msg.channel, "#{msg.nick}: #{tokens[i]}")
	end
end
=end

# eightball
bot.on :message do |msg|
	case msg.message
	when /^.eightball (\S+ ?)+\?$/ then
				responses = [ "It is certain",
				  "It is decidedly so",
				  "Without a doubt",
				  "Yes definitely",
				  "You may rely on it",
				  "As I see it, yes",
				  "Most likely",
				  "Outlook good",
				  "Yes",
				  "Signs point to yes",
				  "Reply hazy try again",
				  "Ask again later",
				  "Better not tell you now",
				  "Cannot predict now",
				  "Concentrate and ask again",
				  "Don\'t count on it",
				  "My reply is no",
				  "My sources say no",
				  "Outlook not so good",
				  "Very doubtful"
			  	]

		responses.shuffle!
		bot.privmsg(msg.channel, "#{msg.nick}: #{responses[0]}")
	end
end

# roll
bot.on :message do |msg|
	case msg.message
	when /^`roll (\d+)D(\d+)/i then
		numbers = msg.message.split(" ")[1].split("D").map(&:to_i)
		rolls = []
		0.upto(numbers[0] - 1) do |i|
			t = rand(numbers[1])
			rolls.push(t.to_i)
		end

		sum = rolls.reduce(:+)

		bot.privmsg(msg.channel, "#{msg.nick}: #{sum}")
		
	end
end

# waifu
bot.on :message do |msg|
	case msg.message
	when /^`waifu --set (\S+ ?)+$/ then
		# set the waifu name
		if $users.include? msg.nick
			waif = ""
			tokens = msg.message.split(" ")
			2.upto(tokens.length - 1) { |i| waif.concat("#{tokens[i]} ") }
			waif = waif[0..-2].to_s
			$waifus[msg.nick].setWaifu(waif)
			bot.privmsg(msg.channel, "#{msg.nick}: waifu set")
			saveWaifus
		else
			temp = Waifu.new
			$waifus.store(msg.nick, temp)
			$users.push(msg.nick)
			waif = ""
			tokens = msg.message.split(" ")
			2.upto(tokens.length - 1) { |i| waif.concat("#{tokens[i]} ") }
			waif = waif[0..-2].to_s
			$waifus[msg.nick].setWaifu(waif)
			bot.privmsg(msg.channel, "#{msg.nick}: waifu set")
			saveWaifus
		end
	when /^`waifu --add \S+$/ then
		# add a waifu image
		if $users.include? msg.nick
			# puts msg.message.split(" ")[2]
			$waifus[msg.nick].addUrl(msg.message.split(" ")[2])
			bot.privmsg(msg.channel, "#{msg.nick}: waifu added")
			saveWaifus
		else
			temp = Waifu.new
			$waifus.store(msg.nick, temp)
			$users.push(msg.nick)
			msg.message.split(" ")[2]
			$waifus[msg.nick].addUrl(msg.message.split(" ")[2])
			bot.privmsg(msg.channel, "#{msg.nick}: waifu added")
			saveWaifus
		end
	when /^`waifu --del \d+$/ then
		# delete a waifu picture
		if $users.include? msg.nick
			if $waifus[msg.nick].getUrls.length > 0
				$waifus[msg.nick].rmUrl(msg.message.split(" ")[2].to_i)
				bot.privmsg(msg.channel, "#{msg.nick}: waifu cleared")
				saveWaifus
			else
				bot.privmsg(msg.channel, "you do not have any waifus")
			end
		else
			bot.privmsg(msg.channel, "you do not have any waifus")
		end
	when /^`waifu --save$/ then
		# if admin update the file
		saveWaifus
	when /^`waifu --help$/ then
		# if someone needs help
		h = "usage `waifu [--set <waifu name>] [--add <url>] [--del <number>]"
		bot.privmsg(msg.channel, h)
	when /^`waifu \S+$/ then
		# check the waifu for a certain nick
		if $users.include? msg.message.split(" ")[1]
			r = ""
			r.concat("#{msg.nick}: #{$waifus[msg.message.split(" ")[1]].getWaifu} -- #{$waifus[msg.message.split(" ")[1]].getUrlsString} [#{msg.message.split(" ")[1]}]")			
			bot.privmsg(msg.channel, r)
		else
			bot.privmsg(msg.channel, "#{msg.nick}: #{msg.message.split(" ")[1]} has no waifus")
		end
	when /^`waifu$/ then
		# check your own waifu
		if $users.include? msg.nick
			r = ""
			r.concat("#{msg.nick}: #{$waifus[msg.nick].getWaifu} -- #{$waifus[msg.nick].getUrlsString} [#{msg.nick}]")
			bot.privmsg(msg.channel, r)
		else
			bot.privmsg(msg.channel, "#{msg.nick}: you have no waifus")
		end
	end
end

# bots
bot.on :message do |msg|
	case msg.message
	when /^.bots$/ then
		bot.privmsg(msg.channel, "Reporting in! [Ruby]")
	end
end

# weather
bot.on :message do |msg|

	params = msg.message[9..-1].to_s

	case msg.message
	when /^.weather --save$/ then
		saveWeather
	when /^.weather --help$/ then # .weather [--help]
		h = "usage: .weather [--help] [--set <area code>] [--area <area code>] [nick] NOTE: city state should be given without a ,and with a space"
		bot.privmsg(msg.channel, h)
	when /^.weather --set (\S+ ?)+$/ then # .weather [--set <area code>]
		params = msg.message[15..-1].to_s
		if params.include? " "
			city = params.split(" ")[0].to_s
			state = params.split(" ")[1].to_s
			nickN = msg.nick
			if not $usersW.include? nickN then $usersW.push(nickN) end
			$weather.store(nickN, [city, state])
			bot.privmsg(msg.channel, "weather set [#{msg.nick}]")
			saveWeather
		else
			areaCode = params
			nickN = msg.nick
			if not $usersW.include? nickN then $usersW.push(nickN) end
			$weather.store(nickN, areaCode)
			bot.privmsg(msg.channel, "weather set [#{msg.nick}]")
			saveWeather
		end
	when /^.weather --area (\S+ ?)+$/ then # .weather [--area <area code>]
		params = msg.message[16..-1].to_s
		if params.include? " "
			city = params.split(" ")[0].to_s
			state = params.split(" ")[1].to_s

			weather = getWeather_CS(city, state)
			bot.privmsg(msg.channel, "#{msg.nick}: #{weather}")
		else
			areaCode = params

			weather = getWeather_aC(areaCode)
			bot.privmsg(msg.channel, "#{msg.nick}: #{weather}")
		end
	when /^.weather \S+$/ then # .weather [nick]
		params = msg.message[9..-1].to_s.split(" ")[1].to_s
		if $usersW.include? params then
			args = $weather[params]
			if args.class.to_s =~ /array/i
				weather = getWeather_CS(args[0], args[1])
				bot.privmsg(msg.channel, "#{msg.nick}: #{weather}")
			elsif args.class.to_s =~ /string/i
				weather = getWeather_aC(args)
				bot.privmsg(msg.channel, "#{msg.nick}: #{weather}")
			else
				# user has no weather info
				bot.privmsg(msg.channel, "#{params} has no weather stored")
			end
		else
			bot.privmsg(msg.channel, "#{params} has no weather stored")
		end
	when /^.weather$/ then # .weather
		if $usersW.include? msg.nick then
			args = $weather[msg.nick]
			if args.class.to_s =~ /array/i
				weather = getWeather_CS(args[0], args[1])
				bot.privmsg(msg.channel, "#{msg.nick}: #{weather}")
			elsif args.class.to_s =~ /string/i
				weather = getWeather_aC(args)
				bot.privmsg(msg.channel, "#{msg.nick}: #{weather}")
			else
				# user has no weather info
				bot.privmsg(msg.channel, "#{msg.nick} has no weather stored")
			end
		else
			bot.privmsg(msg.channel, "#{msg.nick} has no weather stored")
		end
	when /^.w --save$/ then
		saveWeather
	when /^.w --help$/ then # .weather [--help]
		h = "usage: .w(eather) [--help] [--set <area code>] [--area <area code>] [nick] NOTE: city state should be given without a ,and with a space"
		bot.privmsg(msg.channel, h)
	when /^.w --set (\S+ ?)+$/ then # .weather [--set <area code>]
		params = msg.message[9..-1].to_s
		if params.include? " "
			city = params.split(" ")[0].to_s
			state = params.split(" ")[1].to_s
			nickN = msg.nick
			if not $usersW.include? nickN then $usersW.push(nickN) end
			$weather.store(nickN, [city, state])
			bot.privmsg(msg.channel, "weather set [#{msg.nick}]")
			saveWeather
		else
			areaCode = params
			nickN = msg.nick
			if not $usersW.include? nickN then $usersW.push(nickN) end
			$weather.store(nickN, areaCode)
			bot.privmsg(msg.channel, "weather set [#{msg.nick}]")
			saveWeather
		end
	when /^.w --area (\S+ ?)+$/ then # .weather [--area <area code>]
		params = msg.message[10..-1].to_s
		if params.include? " "
			city = params.split(" ")[0].to_s
			state = params.split(" ")[1].to_s

			weather = getWeather_CS(city, state)
			bot.privmsg(msg.channel, "#{msg.nick}: #{weather}")
		else
			areaCode = params

			weather = getWeather_aC(areaCode)
			bot.privmsg(msg.channel, "#{msg.nick}: #{weather}")
		end
	when /^.w \S+$/ then # .weather [nick]
		params = msg.message[3..-1].to_s.split(" ")[1].to_s
		if $usersW.include? params then
			args = $weather[params]
			if args.class.to_s =~ /array/i
				weather = getWeather_CS(args[0], args[1])
				bot.privmsg(msg.channel, "#{msg.nick}: #{weather}")
			elsif args.class.to_s =~ /string/i
				weather = getWeather_aC(args)
				bot.privmsg(msg.channel, "#{msg.nick}: #{weather}")
			else
				# user has no weather info
				bot.privmsg(msg.channel, "#{params} has no weather stored")
			end
		else
			bot.privmsg(msg.channel, "#{params} has no weather stored")
		end
	when /^.w$/ then # .weather
		if $usersW.include? msg.nick then
			args = $weather[msg.nick]
			if args.class.to_s =~ /array/i
				weather = getWeather_CS(args[0], args[1])
				bot.privmsg(msg.channel, "#{msg.nick}: #{weather}")
			elsif args.class.to_s =~ /string/i
				weather = getWeather_aC(args)
				bot.privmsg(msg.channel, "#{msg.nick}: #{weather}")
			else
				# user has no weather info
				bot.privmsg(msg.channel, "#{msg.nick} has no weather stored")
			end
		else
			bot.privmsg(msg.channel, "#{msg.nick} has no weather stored")
		end
	end
end

=begin
# pantsu
bot.on :message do |msg|
	case msg.message
	when /^.pantsu --save$/ then
		saveUnderwear
	when /^.pantsu --set (\S+ ?)+$/ then
		if $usersU.include? msg.nick
			# change
			$underwear.store(msg.nick, msg.message[14..-1].to_s)
			bot.privmsg(msg.channel, "pantsu added")
		else
			# add
			$usersU.push(msg.nick)
			$underwear.store(msg.nick, msg.message[14..-1].to_s)
			bot.privmsg(msg.channel, "pantsu added")
		end
	when /^.pantsu (\S+)$/ then
		temp_nick = msg.message.split(" ")[1].to_s
		if $usersU.include? temp_nick
			bot.privmsg(msg.channel, "#{$underwear[temp_nick]} [#{temp_nick}]")
		else
			bot.privmsg(msg.channel, "#{temp_nick} has no pantsu")
		end
	when /^.pantsu$/ then
		temp_nick = msg.nick
		if $usersU.include? temp_nick
			bot.privmsg(msg.channel, "#{$underwear[temp_nick]} [#{temp_nick}]")
		else
			bot.privmsg(msg.channel, "#{temp_nick} has no pantsu")
		end
	end
end
=end

# ignore
bot.on :message do |msg|
	case msg.message
	when /^.ignore add \S+$/ then
		if msg.nick == admins[0]
			bot.add_ignore(msg.message.split(" ")[2].to_s)
			bot.privmsg(msg.channel, "#{msg.message.split(" ")[2].to_s} added to ignore list")
		else
			bot.privmsg(msg.nick, "you are not an admin, this command is not available to non admins")
		end
	end
end

#bot.on :message do |msg|
#	puts msg.message
#end

loadWaifus
loadWeather
loadUnderwear

bot.setup(use_ssl, use_pass, pass, nickserv_pass, channels)
ign_list.each { |tempNick| bot.add_ignore(tempNick) }
bot.start!
