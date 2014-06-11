require 'rubygems'
require 'em-http-request' 
require 'eventmachine' 
require "socket"
require 'yaml'
require 'trollop'
require 'logger'

# This method was taken from http://coderrr.wordpress.com/2008/05/28/get-your-local-ip-address/
def local_ip
  orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true  # turn off reverse DNS resolution temporarily

  UDPSocket.open do |s|
    s.connect '64.233.187.99', 1
    s.addr.last
  end
ensure
  Socket.do_not_reverse_lookup = orig
end

def Process.descendant_processes(base=Process.pid)
  descendants = Hash.new{|ht,k| ht[k]=[k]}
  Hash[*`ps -eo pid,ppid`.scan(/\d+/).map{|x|x.to_i}].each{|pid,ppid|
    descendants[ppid] << descendants[pid]
  }
  descendants[base].flatten - [base]
end

def kill_children
	Process.descendant_processes.each { |p| 
		begin
			# Check to see if the process exists before we try and kill it 
			Process.getpgid(p)
			system "kill -9 #{p}"
		rescue
		end
	}
end

$command_to_run = ""
$kill_bot = false
$is_new_command = false
$current_ip = local_ip
$should_relaunch = true # Used to relaunch the command if it was stopped, it will be false when a new command is used
$num_failed_web_requests = 0
$repeat_command = true
$log_events = false
$log = nil

# This class will check in with the mother-ship. 
# Based on the response there will be different out comes:
#  - The URL specified doesn't return a parsable file or a 200, after ten tries the server will stop
#  - If the URL returns a valid YAML file then it will see if it is a new command based on IP or the default
#    and if so it will launch a new command 
class BotCheckin
	include EM::Deferrable
	@url = ""
	def initialize(url) 
		@url = url
		request = EM::HttpRequest.new(url).get()

		request.errback { handle_failed_request; }
      	request.callback {
      		data = YAML::load(request.response)
      		if(data.is_a?(Array)) 
	      		# Find the server the items is associated with or use the default
	      		data.each do | d | 
	      			if(d["default_entry"]) 
						handle_controller_entry(d)
					elsif d["hosts"].include? $current_ip
						handle_controller_entry(d)
						break
					end
				end
			else
				handle_failed_request
			end
      	}
	end

	def handle_failed_request
		$num_failed_web_requests += 1
		if($num_failed_web_requests > 10) 
			puts "Stopping bot as it failed to connect to #{@url} 10 times"
			EM.stop
		end
	end

	def handle_controller_entry(controller_info) 
		if controller_info["kill_bot"] 
			$kill_bot = true
		elsif(!controller_info["command"].nil? && (controller_info["command"].casecmp($command_to_run) != 0))
			$repeat_command = (controller_info["run_once"]) ? false : true
			$command_to_run = controller_info["command"]
			$is_new_command = true
			$should_relaunch = false
		end 
	end
end

class BotCommand
	include EM::Deferrable

	def initialize(command) 
		d = EM::DeferrableChildProcess.open(command)
		d.callback {|data_from_child|
			if($repeat_command) 
			   	if($should_relaunch) 
			   		if($log_events) 
			   			$log.info "Relaunching \"#{command}\""
			   		end
			   		BotCommand.new(command)
			   	else
			   		# set this back to true as we are probably launching a new 
			   		# command that we will want to keep going.
			   		$should_relaunch = true 
			   	end
			elsif $log_events
				$log.info "Finished running \"#{command}\""
		   	end
		}
	end
end

# Setup command line argument handling 
opts = Trollop::options do
  opt :controller_url, "Specifies the URL where the controller file exists", :type => :string
  opt :log_file, "Tells us where a log should be stored and to turn on loggin", :type => :string
end
Trollop::die :controller_url, "must be specified" if opts[:controller_url].nil? || opts[:controller_url].empty?

# Setup logging if that is wanted
if(!opts[:log_file].nil? && !opts[:log_file].empty?) 
	$log_events = true
	$log = Logger.new(opts[:log_file], 'monthly')
end


EM.run { 
	if($log_events)
		$log.info "Starting the bot - IP address #{$current_ip}"
	end

	EventMachine.add_periodic_timer(1) {
		bot = BotCheckin.new(opts[:controller_url])

		if($kill_bot) 
			if($log_events)
				$log.info "Stopping the bot"
			end
			EM.stop
		end
		
		if($is_new_command) 
			if($log_events) 
				$log.info "Killing current command and starting \"#{$command_to_run}\""
			end
			kill_children
			$is_new_command = false
			$should_relaunch = true
			BotCommand.new($command_to_run)
		end
	}
}

kill_children