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

url           = 'http://data.deichman.no/sparql'
REPO          = RDF::Virtuoso::Repository.new(url)
QUERY         = RDF::Virtuoso::Query
DEFAULT_GRAPH = RDF::URI('http://data.deichman.no/books')

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
        #warn("websocket closed")
        settings.sockets.delete(ws)
      end
    end
end

get '/' do
  # Nysgjerrig på boka?
  slim(:index)  
end

get '/omtale' do
  slim :omtale_dummy
end

get '/omtale/:tnr' do
  # lag bok fra tittelnummer og hent max fire anmeldelser
  book = Book.new(params[:tnr].to_i)
  book.fetch_cover_url unless book.cover_url
  puts book.inspect
  
  reviews = book.fetch_reviews(limit=4)
  #puts reviews.inspect
  unless reviews.count == 0
    slim :omtale, :locals => {:book => book, :reviews => reviews}
  else
    slim :omtale, :locals => {:book => book, :reviews => nil}
  end
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
