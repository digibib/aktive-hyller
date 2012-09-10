require "rdf/virtuoso"
require "nokogiri"
require "faraday"

class Book
  attr_accessor :book_id, :title, :format, :cover_url, :isbn, :creator_id, :creatorName, :responsible, 
                :work_id, :work_isbn, :review_collection, :same_author_collection, :similar_works_collection

  def initialize(tnr)
=begin
  her henter vi det vi trenger i første rekke
  1. Book - den fysiske boka som legges på stasjonen
     @book_id     : bokid (uri)
     @title       : tittel (literal)
     @format      : fysisk format (uri)
     @cover_url   : bilde (uri) hvis på manifestasjon
     @isbn        : (literal)
     @creator     : forfatterid (uri)
     @creatorName : forfatter (literal)
     @responsible : redaktørtekst (literal)
     @work_id     : verksid (uri)
     @work_isbns  : array of isbn uris
     @review_collection       : array of reviews on book
     @same_author_collection  : array of books by same author
=end
    
    @review_collection        = []
    @same_author_collection   = []
    @similar_works_collection = []
    
    accepted_formats = ["http://data.deichman.no/format/Book", "http://data.deichman.no/format/Audiobook"]
    
    url      = 'http://data.deichman.no/resource/tnr_' + tnr.to_s
    @book_id = RDF::URI(url)
    query    = QUERY.select(:title, :format, :isbn, :work_id, :work_isbns, :creator_id, :responsible)
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
      .optional([:work_id, RDF::BIBO.isbn, :work_isbns])
    
    puts "#{query}"
    results       = REPO.select(query)
    
    unless results.empty?
      @title       = results.first[:title]
      @format      = results.first[:format]
      @cover_url   = results.first[:cover_url]
      @isbn        = results.first[:isbn]
      @work_isbns  = results.bindings[:work_isbns].to_a.uniq
      @work_id     = results.first[:work_id]
      @creator_id  = results.first[:creator_id]  
      @creatorName = results.first[:creatorName] unless results.first[:creatorName].to_s.empty?
      @responsible = results.first[:responsible]
    else
      @book_id = nil
    end

    fetch_cover_url(self.book_id) unless self.cover_url
    
    fetch_local_reviews(limit=4)
    fetch_remote_reviews()
    fetch_same_author_books
    
    puts "isbn_array.size: ", @work_isbns.size
  end

  #private
  
  def fetch_cover_url(book_id = self.book_id)
    # Find alternative cover from optionals:
    # 1. other cover from work in same language
    # 2. any other cover from work

    query = QUERY.select(:cover_url, :same_language_image, :any_image)
      .from(DEFAULT_GRAPH)
      .where([book_id, RDF::DC.language, :lang],
             [book_id, RDF::DC.format, self.format])
      .optional([:work, RDF::FABIO.hasManifestation, book_id])
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

  def fetch_local_reviews(limit=nil)
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
    reviews = REPO.select(query)
    # reviews is a graph RDF object, RDF::Query::Solutions
    # http://rdf.rubyforge.org/RDF/Query/Solutions.html
    # can use filter, count, offset, limit, distinct, etc. as on a SPARQL QUERY
    # can also be iterated as RDF::Query::Solution with bindings from query
    reviews.limit(limit) if limit
    for r in reviews
      @review_collection.push({:title => r[:review_title].to_s, :text => r[:review_text].to_s,
        :source => r[:review_source].to_s})
    end
    return @review_collection
  end

  def fetch_remote_reviews
    for remote in %w[getNovelistDescription getBokkildenIngress]
      #break if @review_collection.size >= 4
      temp = self.send(remote.to_sym)
      @review_collection.push(temp) unless temp.nil?
    end
  end

  def getNovelistDescription
    return nil unless @isbn
  
    #TODO undersøke andre muligheter for å få dns til ebscohost
    #     hardkoder ip foreløpig for å ungå treg respons..
    conn = Faraday.new "http://140.234.254.43"

    result = conn.get do |req|
      req.url '/Services/SearchService.asmx/Search'
      req.params['prof'] = 's9001444.main.eit'
      req.params['pwd'] = 'ebs6239'
      req.params['db'] = 'noh'
      req.params['query'] = @isbn
      req.options[:timeout] = 1
    end

    return nil unless result.body

    xml = Nokogiri::XML result.body
    if xml.xpath('//ab').size() >= 1
      nl_description = xml.xpath('//ab').first.content
    end

    return nil unless nl_description
    {:source => "Novelist", :text => nl_description}
  end

  def getBokkildenIngress
    @work_isbns = [@isbn] unless @work_isbns 
    return nil if @work_isbns.empty?

    conn = Faraday.new "http://partner.bokkilden.no"
    bk_ingress = ""
 
    @work_isbns.each do |isbn|
      res = conn.get do |req|
        req.url '/SamboWeb/partner.do'
        req.params['format'] = 'XML'
        req.params['uttrekk'] = 5
        req.params['pid'] = 0
        req.params['ept'] = 3
        req.params['xslId'] = 117
        req.params['enkeltsok'] = isbn
        req.options[:timeout] = 1
      end

      if res.body
        xml = Nokogiri::XML res.body
        if xml.xpath('//Ingress').size() >= 1
          bk_ingress = xml.xpath('//Ingress').first.content
        end
        break unless bk_ingress.empty?
      end
    end

    return nil if bk_ingress.empty?
    {:text => bk_ingress, :source => "Bokkilden"}
  end
  
  def fetch_same_author_books
    # this query fetches other books by same author
    query = QUERY.select(:book, :title, :cover_url)
      .group_digest(:creatorName, ', ', 1000, 1)
      .distinct
      .from(DEFAULT_GRAPH)
      .where(
        [self.book_id, RDF::DC.creator, :creator],
        [:work, RDF::FABIO.hasManifestation, self.book_id],
        [:book, RDF::DC.format, RDF::URI('http://data.deichman.no/format/Book')],
        [:book, RDF::DC.creator, :creator],
        [:creator, RDF::FOAF.name, :creatorName],
        [:book, RDF::DC.title, :title])
      .optional([:book, RDF::FOAF.depiction, :cover_url])
      .minus([:work, RDF::FABIO.hasManifestation, :book])
    
    puts "#{query}"
    results = REPO.select(query)
    unless results.empty?
      results.each do |book| 
      @same_author_collection.push({
        :book => book[:book], 
        :title => book[:title], 
        :cover_url => book[:cover_url] ? book[:cover_url] : fetch_cover_url(book[:book]), 
        :creatorName => book[:creatorName]
        })
      end
    end
  end

  def fetch_related_books
    # this query fetches related books
  query = <<-eoq
PREFIX foaf: <http://xmlns.com/foaf/0.1/>
PREFIX dct: <http://purl.org/dc/terms/>
PREFIX fabio: <http://purl.org/spar/fabio/>
PREFIX deich: <http://data.deichman.no/>

select distinct ?book ?authorName ?title where {
 <#{self.book_id.to_s}> dct:creator ?creator .
 ?creator foaf:name ?authorName .
 ?work fabio:hasManifestation <#{self.book_id.to_s}> .
 {?work deich:similarWork ?similarWork .} UNION {?work deich:autoGeneratedSimilarity ?similarWork .}
 ?similarWork fabio:hasManifestation ?book .
 MINUS {?work fabio:hasManifestation ?book .}
 MINUS {?book dct:creator ?creator .}
 ?book dct:format <http://data.deichman.no/format/Book> ;
  dct:title ?title ;
  dct:language ?lang .
 OPTIONAL { ?book foaf:depiction ?image .}
}
eoq
=begin
    query = QUERY.select(:book, :title, :cover_url)
      .group_digest(:creatorName, ', ', 1000, 1)
      .distinct
      .from(DEFAULT_GRAPH)
      .where(
        [self.book_id, RDF::DC.creator, :creator],
        [:creator, RDF::FOAF.name, :creatorName],
        [:work, RDF::FABIO.hasManifestation, self.book_id])
      .union([:work, RDF::DEICHMAN.similarWork, :similarWork])
      .union([:work, RDF::DEICHMAN.autoGeneratedSimilarity, :similarWork])
      .where([:similarWork, RDF::FABIO.hasManifestation, :book])
      .optional([:book, RDF::FOAF.depiction, :cover_url])
      .minus([:work, RDF::FABIO.hasManifestation, :book])
      .minus([:book, RDF::DC.creator, :creator])
      .where(
        [:book, RDF::DC.format, RDF::URI('http://data.deichman.no/format/Book')],
        [:book, RDF::DC.title, :title],
        [:book, RDF::DC.language, :lang])
      .optimize!
=end    
    puts "#{query}"
    results = REPO.select(query)
    unless results.empty?
      results.each do |related_book| 
      @related_books_collection.push({
        :book => related_book[:book], 
        :title => related_book[:title], 
        :cover_url => related_book[:cover_url] ? related_book[:cover_url] : fetch_cover_url(related_book[:book]), 
        :creatorName => related_book[:creatorName]
        })
      end
    end
  end  
  
end
