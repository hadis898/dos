Setup
=====

 * Make sure Ruby 1.9 is installed
 * Run from the command-line `gem install bundler`
 * Then run `bundle install`

Usage
-----
 * Modify example.yaml to add in the URLs you wish to attack
 * Run the ddos_tester like example below

	```
	ruby ddos_tester.rb <YAML_FILE_HOLDING_URLS> <MAX_CONCURRENCY>[1-200 optional]
	```