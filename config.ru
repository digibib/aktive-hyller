require 'rubygems'
require 'sinatra'
require 'faye/websocket'

require File.join(File.dirname(__FILE__), 'app')
set :run, false
set :server, :puma
set :environment, :production
set :app_file,     'app.rb'

Faye::WebSocket.load_adapter('puma')

ENV['WEBSOCKET_PORT'] = '4567'


run Sinatra::Application
