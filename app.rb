#encoding: UTF-8
require "rubygems"
require "bundler/setup"
require "sinatra"
require "sinatra-websocket"
require "sinatra/reloader" if development?
require "slim"
require "json"

require_relative "./lib/vocabularies.rb"
require_relative "./lib/book.rb"

# Global constants
url           = 'http://data.deichman.no/sparql'
REPO          = RDF::Virtuoso::Repository.new(url)
QUERY         = RDF::Virtuoso::Query
DEFAULT_GRAPH = RDF::URI('http://data.deichman.no/books')

# Sinatra configs
session = {}
set :server, 'thin'
set :sockets, []

# Routing
get '/' do
  # Nysgjerrig på boka?
  slim(:index)  
end

get '/omtale' do
  # Ikke i bruk
  redirect '/omtale/' + session[:book].book_id.to_s.match(/tnr_(.*)/)[1]
end

post '/omtale' do
  # strekkode inn:
  tnr = params[:barcode][4,7]
  puts tnr
  redirect '/omtale/' + tnr
end

get '/omtale/:tnr' do
  # lag bok fra tittelnummer og hent max fire anmeldelser
  session[:book] = Book.new(params[:tnr].strip.to_i)
 
  slim :omtale, :locals => {:book => session[:book]}
end

get '/flere' do
  # Flere bøker av forfatteren
  slim :flere, :locals => {:book => session[:book]}
end

get '/relaterte' do
  # Noe som ligner, relaterte bøker
  slim :relaterte, :locals => {:book => session[:book]}
end

get '/historikk' do
  # Titler som har vært vist i omtalevisning. Nullstilles når man kommer til
  # nysgjerrig på boka-siden.
  'historikk'
end

get '/ws' do
  # handles the messages from the RFID-reader
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
      #warn("websocket closed")
      settings.sockets.delete(ws)
    end
  end
end
