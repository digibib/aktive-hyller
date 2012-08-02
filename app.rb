#encoding: UTF-8
require "rubygems"
require 'sinatra'
require 'sinatra-websocket'
require 'slim'

set :server, 'thin'
set :sockets, []

get '/ws' do
  return false unless request.websocket?

  request.websocket do |ws|
    
    ws.onopen do
      settings.sockets << ws
    end
    
    ws.onmessage do |msg|
      puts msg
      EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
    end
    
    ws.onclose do
      #warn("wetbsocket closed")
      settings.sockets.delete(ws)
    end
  end
end

get '/' do
  # Nysgjerrig på boka?
  slim(:index)  
end

get '/omtale' do
  "omtale for #{params[:tnr]}"
end

get '/flere' do
  'flere bøker av forfatteren'
end

get '/relaterte' do
  'Noe som ligner'
end

get '/historikk' do
  'historikk'
end