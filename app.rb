#encoding: UTF-8
require "rubygems"
require 'sinatra'
require 'sinatra-websocket'
require 'slim'
require "sparql/client"
require "json"

sparql = SPARQL::Client.new("http://data.deichman.no/sparql")

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
  slim(:omtale)
  #"omtale for #{params[:tnr]}"
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

get '/book/:tnr' do
  content_type :json

  accepted_formats = ["http://data.deichman.no/format/Book", "http://data.deichman.no/format/Audiobook"]

  query = 
  <<-eos
    PREFIX dct: <http://purl.org/dc/terms/>
    select ?title ?format where {
    <http://data.deichman.no/resource/tnr_#{params[:tnr].to_i}> dct:title ?title ;
    dct:format ?format . }
  eos

  results = sparql.query(query)

  halt 400, "ugyldig tittelnummer" unless results.size > 0

  {:title => results[0][:title].value,
   :accepted_format => accepted_formats.include?(results[0][:format].to_s) }.to_json
end