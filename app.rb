#encoding: UTF-8
require "rubygems"
require "bundler/setup"
require "sinatra"
require "sinatra-websocket"
require "sinatra/reloader" if development?
require "slim"
require "json"
require "logger"
require_relative "./lib/vocabularies.rb"
require_relative "./lib/book.rb"

# Loggin setup
root = ::File.dirname(__FILE__)
logfile = ::File.join(root,'logs','requests.log')
class ::Logger; alias_method :write, :<<; end
logger  = ::Logger.new(logfile,'weekly')
#use Rack::CommonLogger, logger

# Global constants
url           = 'http://data.deichman.no/sparql'
REPO          = RDF::Virtuoso::Repository.new(url)
QUERY         = RDF::Virtuoso::Query
DEFAULT_GRAPH = RDF::URI('http://data.deichman.no/books')

# Sinatra configs
session = {}
session[:history] = []
set :server, 'thin'
set :sockets, []


# Routing
get '/' do
  session[:history] = []
  # Nysgjerrig på boka?
  logger.info("Sesjon - -")
  slim(:index)
end

get '/timeout' do
  logger.info("Timeout - -")
  redirect('/')
end

get '/omtale' do
  #redirect '/omtale/' + session[:book].book_id.to_s.match(/tnr_(.*)/)[1]
  redirect '/' unless session[:book]
  session[:history].push({:tnr => session[:book].book_id,
                          :title => session[:book].title,
                          :cover_url => session[:book].cover_url,
                          :creatorName => session[:book].creatorName})
  logger.info("Omtalevisning #{session[:book].book_id} #{session[:book].review_collection.size}")
  slim :omtale, :locals => {:book => session[:book], :history => session[:history].uniq}
end

get '/checkformat/:tnr' do
  content_type :json
  accepted_formats = ["http://data.deichman.no/format/Book", "http://data.deichman.no/format/Audiobook", "http://data.deichman.no/format/Compact_Disc"]

  url      = 'http://data.deichman.no/resource/tnr_' + params[:tnr].strip.to_i.to_s
  @book_id = RDF::URI(url)
  query    = QUERY.select(:title, :format).from(DEFAULT_GRAPH)
  query.where([@book_id, RDF::DC.title, :title],
             [@book_id, RDF::DC.format, :format])
  results  = REPO.select(query)
  unless results.empty?
    if accepted_formats.include?(results.first[:format].to_s)
      {:accepted_format => true, :title => results.first[:title].to_s}.to_json
    else
      {:accepted_format => false}.to_json
    end
  else
    "no results"
  end
end

get '/populate/:tnr' do
  session[:book_new] = Book.new(params[:tnr].strip.to_i)
  "success!"
end

get '/copy' do
  session[:book] = session[:book_new]
end

get '/omtale/:tnr' do
  # lag bok fra tittelnummer og hent max fire anmeldelser
  session[:book] = Book.new(params[:tnr].strip.to_i)
  session[:history].push ({:tnr => session[:book].book_id,
                          :title => session[:book].title,
                          :cover_url => session[:book].cover_url,
                          :creatorName => session[:book].creatorName})
  slim :omtale, :locals => {:book => session[:book], :history => session[:history].uniq}
end

get '/flere' do
  # Flere bøker av forfatteren
  logger.info("Flere - #{session[:book].same_author_collection.size}")
  slim :flere, :locals => {:book => session[:book], :history => session[:history].uniq}
end

get '/relaterte' do
  # Noe som ligner, relaterte bøker
  logger.info("Relaterte - #{session[:book].similar_works_collection.size}")
  slim :relaterte, :locals => {:book => session[:book], :history => session[:history].uniq}
end

get '/historikk' do
  # Titler som har vært vist i omtalevisning. Nullstilles når man kommer til
  # nysgjerrig på boka-siden.
  logger.info("Historikk - #{session[:history].uniq.size}")
  slim :historikk, :locals => {:book => session[:book], :history => session[:history].uniq.reverse}
end

get '/ws' do
  # handles the messages from the RFID-reader
  return false unless request.websocket?

  request.websocket do |ws|

    ws.onopen do
      settings.sockets << ws
    end

    ws.onmessage do |msg|
      logger.info("RFID #{msg} -")
      EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
    end

    ws.onclose do
      #warn("websocket closed")
      settings.sockets.delete(ws)
    end
  end
end
