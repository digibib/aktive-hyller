#encoding: UTF-8
require "rubygems"
require "bundler/setup"
require 'sinatra'
require 'sinatra-websocket'
require "sinatra/reloader" if development?
require 'slim'
require "rdf/virtuoso"
require "json"

url = 'http://data.deichman.no/sparql'
repo = RDF::Virtuoso::Repository.new(url)
QUERY = RDF::Virtuoso::Query

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
  slim :omtale
end

get '/omtale/:tnr' do
  tnr = params[:tnr].to_i
  #her henter vi det vi trenger
  #1. CurrentBook
  # 
  query = QUERY.select(:s, :p).where([:s, :p, RDF::URI("http://data.deichman.no/resource/tnr_" + tnr.to_s)])
          .from(RDF::URI("http://data.deichman.no/reviews"))
  puts query
  result = repo.select(query)
  puts result.bindings
  result.bindings.to_json
end

get '/flere' do
  books = ["Bok En", "Bok to", "Bok tre", "Bok 4", "Bok5", "Bok 6", "Bok 7", "Bok 8"]
  slim :flere, :locals => {:books => books}
end

get '/relaterte' do
  'Noe som ligner'
end

get '/historikk' do
  'historikk'
end
