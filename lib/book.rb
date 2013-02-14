require "rdf/virtuoso"
require "nokogiri"
require "faraday"

class Book
  attr_accessor :book_id, :title, :format, :cover_url, :isbn, :creator_id, :creatorName, :responsible, :ratings,
                :work_id, :work_isbn, :review_collection, :same_author_collection, :similar_works_collection, :abstract

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
     @abstract    : 520-note
     @review_collection       : array of reviews on book
     @same_author_collection  : array of books by same author
     @ratings                 : array of ratings
=end
    
    @ratings                  = [] # ratings format {:source, :num_raters, :rating}
    @review_collection        = []
    @same_author_collection   = []
    @similar_works_collection = []
    
    url      = 'http://data.deichman.no/resource/tnr_' + tnr.to_s
    @book_id = RDF::URI(url)
    query    = QUERY.select(:title, :format, :isbn, :work_id, :creator_id, :responsible, :abstract)
    query.distinct.from(DEFAULT_GRAPH)
    query.sample(:cover_url, :workAbstract)
    query.group_digest(:creatorName, ', ', 1000, 1)
    query.where([@book_id, RDF::DC.title, :title],
             [@book_id, RDF::DC.language, :lang],
             [@book_id, RDF::DC.format, :format])
    query.optional([@book_id, RDF::FOAF.depiction, :cover_url])
    query.optional([@book_id, RDF::DC.abstract, :abstract])
    query.optional([@book_id, RDF::BIBO.isbn, :isbn])
    query.optional([@book_id, RDF::DC.creator, :creator_id],
                [:creator_id, RDF::FOAF.name, :creatorName])
    query.optional([@book_id, RDF::RDA.statementOfResponsibility, :responsible])
    query.optional([:work_id, RDF::FABIO.hasManifestation, @book_id])
    query.optional([:work_id, RDF::FABIO.hasManifestation, :book],
                [:book, RDF::DC.abstract, :workAbstract])
    
    puts "#{query}"
    results       = REPO.select(query)
    
    unless results.empty?
      @title       = results.first[:title]
      @format      = results.first[:format]
      @cover_url   = results.first[:cover_url]
      @isbn        = results.first[:isbn].to_s if results.first[:isbn]
      @work_id     = results.first[:work_id]
      @creator_id  = results.first[:creator_id]  
      @creatorName = results.first[:creatorName] unless results.first[:creatorName].to_s.empty?
      @responsible = results.first[:responsible]
      unless results.first[:abstract].to_s.empty?
        @abstract  = results.first[:abstract]
      else
        @abstract  = results.first[:workAbstract] unless results.first[:workAbstract].to_s.empty?
      end

      # fetch isbns for work into array
      if @work_id
        query = QUERY.select(:work_isbns)
        query.select.where([@work_id, RDF::BIBO.isbn, :work_isbns])
        puts "#{query}"
        results     = REPO.select(query)
        @work_isbns = results.bindings[:work_isbns].to_a.uniq
      end
      # return either cover_url, same_language_image or any_image
      unless @cover_url
        @cover_url = fetch_cover_url(@book_id)
      end
    else
      @book_id = nil
    end

    #fetch_cover_url(self.book_id) unless self.cover_url
    
    fetch_local_reviews(limit=4)
    fetch_remote_data
    fetch_same_author_books
    fetch_similar_works
    
    puts "isbn_array: ", @work_isbns
  end

  #private
  
  def fetch_cover_url(book_id = self.book_id)
    # Find alternative cover from optionals:
    # 1. other cover from work in same language
    # 2. any other cover from work
    # or return nil
    query = QUERY.select.sample(:same_language_format_image, :same_language_image, :any_image)
      .from(DEFAULT_GRAPH)
      .where([book_id, RDF::DC.language, :lang])
      .optional([:work, RDF::FABIO.hasManifestation, book_id])
      .optional([:work, RDF::FABIO.hasManifestation, :same_language_format_book],
           [:same_language_format_book, RDF::DC.language, :lang],
           [:same_language_format_book, RDF::DC.format, self.format],
           [:same_language_format_book, RDF::FOAF.depiction, :same_language_format_image])
      .optional([:work, RDF::FABIO.hasManifestation, :same_language_book],
           [:same_language_book, RDF::DC.language, :lang],
           [:same_language_book, RDF::FOAF.depiction, :same_language_image])
      .optional([:work, RDF::FABIO.hasManifestation, :any_book],
           [:any_book, RDF::FOAF.depiction, :any_image],
           [:any_book, RDF::DC.format, self.format])

    #puts query              
      
    results = REPO.select(query)
    #puts results
    # return either same_language_image or any_image
    results.first[:same_language_format_image] ? results.first[:same_language_format_image] : results.first[:same_language_image] ? results.first[:same_language_image] : results.first[:any_image]
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
        query.where([:review_id, RDF::DEICH.basedOnManifestation, self.book_id])
      end
      query.where([:review_id, RDF::REV.title, :review_title],
                  [:review_id, RDF::REV.text, :review_text])
      query.optional([:review_id, RDF::DC.source, :source_id],
                     [:source_id, RDF::FOAF.name, :review_source])
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
    @review_collection.push({:text => @abstract.to_s, :source => "Katalogpost"}) if @abstract
    return @review_collection
  end

  def fetch_remote_data
    for remote in %w[Novelist Bokkilden Goodreads Bokelskere]
      #break if @review_collection.size >= 4
      self.send(remote.to_sym)
    end
  end

  def Goodreads
    return nil unless @isbn

    timing_start = Time.now
    conn = Faraday.new "http://www.goodreads.com"
    gr_description = nil

    begin
      result = conn.get do |req|
        req.url '/book/isbn'
        req.params['isbn'] = @isbn
        req.params['key'] = "wDjpR0GY1xXIqTnx2QL37A"
        req.params['format'] = 'xml'
        req.options[:timeout] = 2
        req.options[:open_timeout] = 2
      end
    rescue Faraday::Error::TimeoutError
      puts "\nDEBUG:timeout getting data from GoodReads after #{Time.now - timing_start} seconds\n"
    end
    

    return nil unless result.body
    return nil if result.body =~ /book not found/
    xml = Nokogiri::XML result.body
    gr_description = xml.xpath('//description').first.content unless xml.xpath('//description').first.content.strip.empty?
    gr_num_raters = xml.xpath('//ratings_count').first.content.to_i
    gr_rating = xml.xpath('//ratings_sum').first.content.to_i

    @ratings.push({:rating => gr_rating, :num_raters => gr_num_raters, :source=>"GoodReads"}) if gr_rating
    @review_collection.push({:source => "GoodReads", :text => gr_description}) if gr_description
  end

  def Bokelskere
    return nil unless @isbn
    puts "isbn til bokelskere: ", @isbn
    
    timing_start = Time.now
    conn = Faraday.new "http://bokelskere.no"
    begin
      result = conn.get do |req|
        req.url '/api/1.0/boker/info/' + @isbn.to_s + '/'
        #req.params['format'] = 'json'
        req.options[:timeout] = 2
        req.options[:open_timeout] = 4
      end
    rescue Faraday::Error::TimeoutError
      puts "\nDEBUG:timeout getting data from Bokelskere after #{Time.now - timing_start} seconds\n"
      result = nil
    end
    
    return nil unless result.body
    return nil if result.body.strip.empty?
    return nil if result.body =~ /Not Found/

    jsonres = JSON.parse(result.body) 
    if jsonres['antall_terningkast'].to_i > 0
      be_rating = jsonres['gjennomsnittelig_terningkast']
      be_num_raters = jsonres['antall_terningkast']
      @ratings.push( {:rating => be_rating, :num_raters => be_num_raters, :source => "Bokelskere"})
    end
  end

  def Novelist
    return nil unless @isbn
  
    timing_start = Time.now

    #TODO undersøke andre muligheter for å få dns til ebscohost
    #     hardkoder ip foreløpig for å ungå treg respons..
    conn = Faraday.new "http://140.234.254.43"

    begin
      result = conn.get do |req|
        req.url '/Services/SearchService.asmx/Search'
        req.params['prof'] = 's9001444.main.eit'
        req.params['pwd'] = 'ebs6239'
        req.params['db'] = 'noh'
        req.params['query'] = @isbn
        req.options[:timeout] = 1
        req.options[:open_timeout] = 2
      end
    rescue Faraday::Error::TimeoutError
      puts "\nDEBUG:timeout getting data from Novelist after #{Time.now - timing_start} seconds\n"
    end

    return nil if result.nil?

    xml = Nokogiri::XML result.body
    if xml.xpath('//ab').size() >= 1
      nl_description = xml.xpath('//ab').first.content
    end

    return nil unless nl_description
    @review_collection.push({:source => "Novelist", :text => nl_description})
  end

  def Bokkilden
    @work_isbns = [@isbn] unless @work_isbns 
    return nil if @work_isbns.empty?

    timing_start = Time.now
    conn = Faraday.new "http://partner.bokkilden.no"
    bk_ingress = ""
 
    begin
      @work_isbns.each do |isbn|
        res = conn.get do |req|
          req.url '/SamboWeb/partner.do'
          req.params['format'] = 'XML'
          req.params['uttrekk'] = 5
          req.params['pid'] = 0
          req.params['ept'] = 3
          req.params['xslId'] = 117
          req.params['enkeltsok'] = isbn
          req.options[:timeout] = 3
          req.options[:open_timeout] = 4
        end

        if res.body
          xml = Nokogiri::XML res.body
          if xml.xpath('//Ingress').size() >= 1
            bk_ingress = xml.xpath('//Ingress').first.content
          end
          break unless bk_ingress.empty?
        end
      end
    rescue Faraday::Error::TimeoutError
      puts "\nDEBUG:timeout getting data from Bokkilden after #{Time.now - timing_start} seconds\n"
    end

    return nil if bk_ingress.empty?
    @review_collection.push({:text => bk_ingress, :source => "Bokkilden"})
  end
  
  def fetch_same_author_books
    # this query fetches other works by same author
    query = QUERY.select(:similar_work, :lang, :original_language, :book_title, :book)
      .sample(:cover_url)
      .group_digest(:creatorName, ', ', 1000, 1)
      .distinct
      .from(DEFAULT_GRAPH)
      .where(
        [self.book_id, RDF::DC.creator, :creator],
        [:work, RDF::FABIO.hasManifestation, self.book_id],
        [:similar_work, RDF::FABIO.hasManifestation, :book],
        [:book, RDF::DC.format, RDF::URI('http://data.deichman.no/format/Book')],
        [:book, RDF::DC.language, :lang],
        [:similar_work, RDF::DC.creator, :creator],
        [:creator, RDF::FOAF.name, :creatorName],
        [:book, RDF::DC.title, :book_title])
      .optional([:book, RDF::FOAF.depiction, :cover_url])
      .optional([:book, RDF::DEICH.originalLanguage, :original_language])
      .minus([:work, RDF::FABIO.hasManifestation, :book])
    
    puts "Her: #{query}"
    solutions = REPO.select(query)
    results = select_manifestations(solutions)
    return nil unless results
    results.each do |same_author_books| 
    @same_author_collection.push({
      :book => same_author_books[:book], 
      :title => same_author_books[:book_title], 
      :cover_url => same_author_books[:cover_url] ? same_author_books[:cover_url] : fetch_cover_url(same_author_books[:book]), 
      :creatorName => same_author_books[:creatorName]
      })
    end
  end

  def fetch_similar_works
    # this query fetches related books
    similaritygraph = {:context => RDF::URI('http://data.deichman.no/noeSomLigner')}
    bookgraph       = {:context => RDF::URI("http://data.deichman.no/books")}

    query = QUERY.select(:book, :book_title, :lang, :original_language, :similar_work)
    query.sample(:cover_url)
    query.group_digest(:creatorName, ', ', 1000, 1)
    query.distinct
    query.where(
        [:work, RDF.type, RDF::FABIO.Work, bookgraph],
        [:work, RDF::FABIO.hasManifestation, book_id, bookgraph],
        [:work, RDF::DC.creator, :creator, bookgraph],
        [:similar_work, RDF::type, RDF::FABIO.Work, bookgraph],
        [:work, :predicate, :similar_work, similaritygraph],
        [:similar_work, RDF::FABIO.hasManifestation, :book, bookgraph],
        [:book, RDF::DC.title, :book_title, bookgraph],
        [:book, RDF::DC.language, :lang, bookgraph]
        )
    query.optional([:book, RDF::FOAF.depiction, :cover_url, bookgraph])
    query.optional([:book, RDF::DEICH.originalLanguage, :original_language, bookgraph])
    query.optional([:book, RDF::DC.creator, :similar_book_creator, bookgraph],
        [:similar_book_creator, RDF::FOAF.name, :creatorName, bookgraph])
    query.minus([:similar_work, RDF::DC.creator, :creator, bookgraph])
    query.filter('(?predicate = <http://data.deichman.no/similarWork>) || (?predicate = <http://data.deichman.no/autoGeneratedSimilarity>)')
    
    #puts "#{query}"
    solutions = REPO.select(query)
    results = select_manifestations(solutions)
    
    return nil unless results

    results.each do |similar_book| 
      @similar_works_collection.push({
        :book => similar_book[:book], 
        :title => similar_book[:book_title], 
        :cover_url => similar_book[:cover_url] ? similar_book[:cover_url] : fetch_cover_url(similar_book[:book]), 
        :creatorName => similar_book[:creatorName]
        })
    end    
  end  
  
  def select_manifestations(solutions)
    return nil if solutions.empty?
    
    results = []
    # We only want one manifestation of each work
    # Iterate solutions and choose by priorities:
    # 1. lang = nob/nno
    # 2. originalLanguage = eng/swe/dan
    # 3. lang = eng
    # 4. lang = swe
    # 5. lang = dan 
    distinct_works = Marshal.load(Marshal.dump(solutions)).select(:similar_work).distinct
    
    distinct_works.each do |ds|
      catch :found_book do
        solutions.each do |s|
          if ds[:similar_work] == s[:similar_work]
            if s[:lang] == RDF::URI("http://lexvo.org/id/iso639-3/nob") || s[:lang] == RDF::URI("http://lexvo.org/id/iso639-3/nno")
              results << s
              throw :found_book
            end
          end
        end
        solutions.each do |s|
          if ds[:similar_work] == s[:similar_work]
            if s[:original_language] == RDF::URI("http://lexvo.org/id/iso639-3/eng") ||
                s[:original_language] == RDF::URI("http://lexvo.org/id/iso639-3/swe") ||
                s[:original_language] == RDF::URI("http://lexvo.org/id/iso639-3/dan")
              results << s
              throw :found_book
            end
          end
        end      
        solutions.each do |s|
          if ds[:similar_work] == s[:similar_work]
            if s[:lang] == RDF::URI("http://lexvo.org/id/iso639-3/eng") || 
                s[:lang] == RDF::URI("http://lexvo.org/id/iso639-3/swe") ||
                s[:lang] == RDF::URI("http://lexvo.org/id/iso639-3/dan")
              results << s
              throw :found_book
            end
          end
        end 
      end         
    end
    
    return results
  end  
end
