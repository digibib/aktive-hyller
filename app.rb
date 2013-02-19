#encoding: UTF-8
require_relative "./config/init.rb"

require "sinatra"
require "sinatra-websocket"
require "sinatra/reloader" if development?
require "slim"
require "json"
require "logger"

root = ::File.dirname(__FILE__)

# load init.rb
require File.join(root, 'config', 'init.rb')

# Logging setup

logfile = ::File.join(root,'logs','requests.log')
class ::Logger; alias_method :write, :<<; end
logger  = ::Logger.new(logfile,'weekly')
#use Rack::CommonLogger, logger

# Sinatra configs
set :server, 'thin'
set :sockets, []

# In-memory session object
session = {}
session[:books] = {}    # {:tnr => book_object}
session[:history] = []  # Array of Hash
                        # ex: {:path => "/omtale" :book => session[:books][:tnr]}
session[:current] = nil # Current book in session

# before each request
before do
  session[:locale] = params[:locale] if params[:locale]
  @history = session[:history]
end

# Routing
get '/' do
  # Nysgjerrig på boka?

  # Clear session history
  session[:history] = []
  logger.info("Sesjon - -")

  slim(:index, :layout => false)
end

get '/timeout' do
  logger.info("Timeout - -")
  redirect('/')
end

get '/omtale' do
  redirect '/' unless session[:current]

  session[:history].push({:path => '/omtale', :tnr => session[:current].tnr})
  logger.info("Omtalevisning #{session[:current].book_id} #{session[:current].review_collection.size}")
  slim :omtale, :locals => {:book => session[:current]}
end

get '/omtale/:tnr' do
  # Help route to fetch book manually by tnr
  tnr = params[:tnr].strip.to_i
  session[:books][tnr] = Book.new(tnr)
  session[:current] = session[:books][tnr]

  redirect '/omtale'
end

get '/flere' do
  # Flere bøker av forfatteren

  session[:history].push({:path => '/flere', :tnr => session[:current].tnr})
  logger.info("Flere - #{session[:current].same_author_collection.size}")
  slim :flere, :locals => {:book => session[:current]}
end

get '/relaterte' do
  # Noe som ligner, relaterte bøker

  session[:history].push({:path => '/relaterte', :tnr => session[:current].tnr})
  logger.info("Relaterte - #{session[:current].similar_works_collection.size}")
  slim :relaterte, :locals => {:book => session[:current]}
end

get '/back' do
  # Route to trigger history -1 - works like browsers back-button

  session[:history] = session[:history][0...-1]
  back = session[:history].pop
  session[:current] = session[:books][back[:tnr]]
  redirect back[:path]
end

get '/checkformat/:tnr' do
  content_type :json
  accepted_formats = [RDF::URI("http://data.deichman.no/format/Book"),
                      RDF::URI("http://data.deichman.no/format/Audiobook")]

  url      = 'http://data.deichman.no/resource/tnr_' + params[:tnr].strip.to_i.to_s
  @book_id = RDF::URI(url)
  query    = QUERY.select(:title, :format).from(DEFAULT_GRAPH)
  query.where([@book_id, RDF::DC.title, :title],
             [@book_id, RDF::DC.format, :format])
  results  = REPO.select(query)
  unless results.empty?
    if !(accepted_formats & results.bindings[:format]).empty?
      {:accepted_format => true, :title => results.first[:title].to_s}.to_json
    else
      {:accepted_format => false}.to_json
    end
  else
    "no results"
  end
end

get '/populate/:tnr' do
  tnr = params[:tnr].strip.to_i
  session[:books][:new] = session[:books][tnr] || Book.new(tnr)
  "success!"
end

get '/copy' do
  tnr = session[:books][:new].tnr
  session[:books][tnr] = session[:books][:new]
  session[:current] = session[:books][tnr]
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
