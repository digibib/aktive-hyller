#encoding: UTF-8
require "rubygems"
require 'sinatra'
require 'sinatra-websocket'
require "sinatra/reloader" if development?
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
  slim :omtale 
  #"omtale for #{params[:tnr]}"
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

get '/more_info/:tnr' do
  content_type :json

  query = 
  <<-eos
  PREFIX rda: <http://rdvocab.info/Elements/>
  PREFIX dct: <http://purl.org/dc/terms/>
  PREFIX foaf: <http://xmlns.com/foaf/0.1/>
  PREFIX bibo: <http://purl.org/ontology/bibo/>
  PREFIX fabio: <http://purl.org/spar/fabio/>
  SELECT
  ?title ?responsible (sql:GROUP_DIGEST(?creatorName, ', ', 1000, 1)) as ?creatorName ?format ?isbn ?work
  (sql:sample(?img)) as ?img
  WHERE {
   GRAPH <http://data.deichman.no/books> {
    <http://data.deichman.no/resource/tnr_#{params[:tnr].to_i}> dct:title ?title ;
     dct:format ?format .
    OPTIONAL { <http://data.deichman.no/resource/tnr_#{params[:tnr].to_i}> bibo:isbn ?isbn . }
    OPTIONAL { <http://data.deichman.no/resource/tnr_#{params[:tnr].to_i}> dct:creator ?creator .
               ?creator foaf:name ?creatorName . }
    OPTIONAL { <http://data.deichman.no/resource/tnr_#{params[:tnr].to_i}> rda:statementOfResponsibility ?responsible .}
    OPTIONAL { ?work fabio:hasManifestation <http://data.deichman.no/resource/tnr_#{params[:tnr].to_i}> . }
    OPTIONAL { <http://data.deichman.no/resource/tnr_#{params[:tnr].to_i}> foaf:depiction ?img . }
   }
  }
  eos

  results = sparql.query(query)

  halt 400, "ugyldig tittelnummer" unless results.size > 0
  
  results[0].to_hash.to_json
end
