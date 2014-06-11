# General Use
This script was created as a bot to be controlled during DDoS testing.  Since we didn't always have one specific command we wanted to run all the times we wanted a flexible way to execute commands from multiple hosts.  This script was developed with linux based hosts in mind it should work in Windows but no testing was done.  There is a central controlling file that is used for all hosts. 

All bots check the controlling file every second to see if new commands have been specified. If a new command is specified for the given hosts it will kill the current command and launch the new command.  If a command finishes on a bot and the run_once flag isn't set the command will relaunch. 

## Setup

 * Make sure Ruby 1.9 is installed
 * Run from the command-line `gem install bundler`
 * Then run `bundle install`

## Basic Usage

* Modify controller_example.yaml to suit your needs, below are the allowed elements
  * hosts - an array of host IPs that should look at this entry for commands
  * command - a string that should be run for the given hosts
  * default_entry - Setting this to true tells the bot to use this entry as the default if the bot's IP is not found in any of the hosts array
  * kill_bot - Setting this to true will kill the bots associated with in the hosts element
  * run_once - Setting this to true tells the bot to only run a command once and then wait for more commands
* Once the yaml file has been modified upload it to a web server that is accessible to all bots
* Launch bots by using the following command `ruby bot.rb --controller-url <URL_OF_CONTROLLER_FILE>`
* Other options can be found by using the help command `ruby bot.rb --help`