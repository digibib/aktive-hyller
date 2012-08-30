#encoding: UTF-8
require "rubygems"
require "bundler/setup"
require 'sinatra'
require 'sinatra-websocket'
require "sinatra/reloader" if development?
require 'slim'
require "rdf/virtuoso"
require "json"

url           = 'http://data.deichman.no/sparql'
REPO          = RDF::Virtuoso::Repository.new(url)
QUERY         = RDF::Virtuoso::Query
DEFAULT_GRAPH = RDF::URI('http://data.deichman.no/books')

# Extend module RDF with vocabularies we need to use
module RDF
  class BIBO < RDF::Vocabulary("http://purl.org/ontology/bibo/");end
  class RDFS < RDF::Vocabulary("http://www.w3.org/2000/01/rdf-schema#");end
  class XFOAF < RDF::Vocabulary("http://www.foafrealm.org/xfoaf/0.1/")
    property :name
  end
  class LEXVO < RDF::Vocabulary("http://lexvo.org/ontology#")
    property :name
  end
  class DEICHMAN < RDF::Vocabulary("http://data.deichman.no/");end
  class REV < RDF::Vocabulary("http://purl.org/stuff/rev#");end
  class DBO < RDF::Vocabulary("http://dbpedia.org/ontology/");end
  class FABIO < RDF::Vocabulary("http://purl.org/spar/fabio/");end
  class FRBR < RDF::Vocabulary("http://purl.org/vocab/frbr/core#");end  
  class RDA < RDF::Vocabulary("http://rdvocab.info/Elements/");end  
  class GEONAMES < RDF::Vocabulary("http://www.geonames.org/ontology#")
    property :name
  end  
  class MO < RDF::Vocabulary("http://purl.org/ontology/mo/");end
  class YAGO < RDF::Vocabulary("http://dbpedia.org/class/yago/");end 
  class CTAG < RDF::Vocabulary("http://commontag.org/ns#");end 
  class RADATANA < RDF::Vocabulary("http://def.bibsys.no/xmlns/radatana/1.0#");end 
end

class Book
  attr_accessor :book_id, :title, :format, :cover_url, :isbn, :work_id, :creator_id, :creatorName, :responsible

  def initialize(tnr)
=begin
  her henter vi det vi trenger i første rekke
  1. Book - den fysiske boka som legges på stasjonen
     @book_id     : bokid (uri)
     @title       : tittel (literal)
     @format      : fysisk format (uri)
     @cover_url   : bilde (uri) hvis på manifestasjon
     @isbn        : Array (literal)
     @creator     : forfatterid (uri)
     @creatorName : forfatter (literal)
     @responsible : redaktørtekst (literal)
     @work_id     : verksid (uri)
=end
    accepted_formats = ["http://data.deichman.no/format/Book", "http://data.deichman.no/format/Audiobook"]
    url      = 'http://data.deichman.no/resource/tnr_' + tnr.to_s
    @book_id = RDF::URI(url)
    query    = QUERY.select(:title, :format, :isbn, :work_id, :creator_id, :responsible)
    query.from(DEFAULT_GRAPH)
      .sample(:cover_url)
      .group_digest(:creatorName, ', ', 1000, 1)
      .where([@book_id, RDF::DC.title, :title],
            [@book_id, RDF::DC.format, :format])
      .optional([@book_id, RDF::FOAF.depiction, :cover_url])
      .optional([@book_id, RDF::BIBO.isbn, :isbn])
      .optional([@book_id, RDF::DC.creator, :creator_id],
                [:creator_id, RDF::FOAF.name, :creatorName])
      .optional([@book_id, RDF::RDA.statementOfResponsibility, :responsible])
      .optional([:work_id, RDF::FABIO.hasManifestation, @book_id])
    
    puts "#{query}"
    results       = REPO.select(query)
    
    unless results.empty?
      @title      = results.first[:title]
      @format     = results.first[:format]
      @cover_url  = results.first[:cover_url]
      @isbn       = results.first[:isbn] 
      @work_id    = results.first[:work_id]
      @creator_id = results.first[:creator_id]  
      @creatorName = results.first[:creatorName] unless results.first[:creatorName].to_s.empty?
      @responsible = results.first[:responsible]
    else
      @book_id = nil
    end
  end
  
  def fetch_cover_url
    # cover_url accessor already set? return before query is made
    return @cover_url if @cover_url
          
    # Or find alternative cover from optionals:
    # 1. other cover from work in same language
    # 2. any other cover from work

    query = QUERY.select(:cover_url, :same_language_image, :any_image)
      .from(DEFAULT_GRAPH)
      .where([self.book_id, RDF::DC.language, :lang],
             [self.book_id, RDF::DC.format, self.format])
      .optional([:work, RDF::FABIO.hasManifestation, self.book_id])
      .optional([:work, RDF::FABIO.hasManifestation, :another_book],
           [:another_book, RDF::DC.language, :lang],
           [:another_book, RDF::FOAF.depiction, :same_language_image],
           [:another_book, RDF::DC.format, self.format])
      .optional([:work, RDF::FABIO.hasManifestation, :any_book],
           [:any_book, RDF::FOAF.depiction, :any_image],
           [:any_book, RDF::DC.format, self.format])               
      
    results = REPO.select(query)
    found = results.first if results.any?
    # return either same_language_image or any_image
    found[:same_language_image] ? @cover_url = found[:same_language_image] : @cover_url = found[:any_image]
    return @cover_url
  end
  
  def fetch_reviews(limit=nil)
    reviewgraph = RDF::URI('http://data.deichman.no/reviews') 
    # her henter vi omtale
    query = QUERY.select(:review_id, :review_title, :review_text, :review_source, :reviewer)
      query.distinct  
      query.from(reviewgraph)
      if self.work_id
        query.where([:review_id, RDF::DC.subject, self.work_id])
      else
        query.where([:review_id, RDF::DEICHMAN.basedOnManifestation, self.book_id])
      end
      query.where([:review_id, RDF::REV.title, :review_title],
         [:review_id, RDF::REV.text, :review_text])
      query.optional([:review_id, RDF::DC.source, :source_id],
                     [:source_id, RDF::RDFS.label, :review_source])
      query.optional([:review_id, RDF::REV.reviewer, :reviewer])
      query.filter('lang(?review_text) != "nn"')
      
    puts query
    solutions = REPO.select(query)
    reviews = solutions
    reviews.limit(limit) if limit
    return reviews
  end
end


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

  book = Book.new(params[:tnr].to_i)
  book.fetch_cover_url unless book.cover_url
  puts book.inspect
  
  reviews = book.fetch_reviews
  # puts results.bindings
  
  slim :omtale, :locals => {:book => book, :reviews => reviews}
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
