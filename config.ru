require 'rubygems'
require 'sinatra'

set :environment, :production
set :app_file,     'app.rb'
disable :run

require File.join(File.dirname(__FILE__), 'app')
run Sinatra::Application
