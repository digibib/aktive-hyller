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
logger  = ::Logger.new(logfile,'monthly')
logger.datetime_format = "%Y-%m-%dT%H:%M:%S.%L "

#use Rack::CommonLogger, logger

# Sinatra configs
set :server, 'thin'
set :sockets, []

# In-memory session object
session = {}
session[:locale] = 'nb' # default
session[:books] = {}    # {:tnr => book_object}
session[:history] = []  # Array of Hash
                        # ex: {:path => "/omtale" :book => session[:books][:tnr]}
session[:current] = nil # Current book in session
session[:log] = {:start => Time.now, :stop => nil, :rfid => 0, :omtale => 0, :flere => 0, :relaterte => 0}

# before each request
before do
  @history = session[:history]
  # Force locale on each request to counter annoying autodetect
  R18n.set(session[:locale])
end

# Routing
get '/' do
  # Nysgjerrig på boka?

  # Generate session log line
  session[:log][:stop] = Time.now
                       # start stop rfid omtale flere relaterte
  logger.info("Finito #{session[:log][:start].strftime("%Y-%m-%dT%H:%M:%S.%L")} #{session[:log][:stop].strftime("%Y-%m-%dT%H:%M:%S.%L")} #{session[:log][:rfid]} #{session[:log][:omtale]} #{session[:log][:flere]} #{session[:log][:relaterte]}")

  # Clear session history
  session[:history] = []
  session[:current] = nil
  session[:log] = "starting"
  logger.info("Sesjon - -")

  slim(:index, :layout => false)
end

get '/lang/:locale' do
  session[:locale] = params[:locale]
  logger.info("language #{params[:locale]}")

  # Reload page with new locale
  back = session[:history].pop
  redirect back[:path] || '/omtale'
end

get '/timeout' do
  logger.info("Timeout - -")
  redirect('/')
end

get '/omtale' do
  redirect '/' unless session[:current]
  session[:log] = {:start => Time.now, :rfid => 0, :omtale => 0, :flere => 0, :relaterte => 0} if session[:log] == "starting"
  session[:log][:omtale] += 1
  session[:history].push({:path => '/omtale', :tnr => session[:current].tnr})
  logger.info("Omtalevisning #{session[:current].book_id} #{session[:current].review_collection.size} \"#{session[:current].creatorName || session[:current].responsible || 'ukjent'}\" \"#{session[:current].title}\"")
  slim :omtale, :locals => {:book => session[:current], :lang => session[:locale]}
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

  session[:log][:flere] += 1
  session[:history].push({:path => '/flere', :tnr => session[:current].tnr})
  logger.info("Flere \"#{session[:current].creatorName || session[:current].responsible}\" #{session[:current].same_author_collection.size}")
  slim :flere, :locals => {:book => session[:current], :lang => session[:locale]}
end

get '/relaterte' do
  # Noe som ligner, relaterte bøker

  session[:log][:relaterte] += 1
  session[:history].push({:path => '/relaterte', :tnr => session[:current].tnr})
  logger.info("Relaterte \"#{session[:current].creatorName || session[:current].responsible} - #{session[:current].title}\" #{session[:current].similar_works_collection.size}")
  slim :relaterte, :locals => {:book => session[:current], :lang => session[:locale]}
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

  url      = RESOURCE_PREFIX + params[:tnr].strip.to_i.to_s
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

get '/stats/:file' do
  "<pre>#{File.read('logs/'+params[:file]+'.txt')}</pre>"
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
      session[:log][:rfid] += 1
      EM.next_tick { settings.sockets.each{|s| s.send(msg) } }
    end

    ws.onclose do
      #warn("websocket closed")
      settings.sockets.delete(ws)
    end
  end
end

put '/error_report' do
  if SETTINGS["error_report"]["emails"]
    msg = "En feil har blitt oppdaget på tittelnr: #{session[:current].tnr} \n Lykke til med å finne feilen ...;)"
    SETTINGS["error_report"]["emails"].each do |recipient|
      send_error_report(recipient, msg, :subject => "Aktiv hylle - feilmelding!")
      logger.info("Error message sent to #{recipient}")
    end
    "message sent!"
  else
    "no emails to send to!"
  end
end
