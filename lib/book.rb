# encoding: UTF-8
require "rdf/virtuoso"
require "nokogiri"
require "faraday"
require "typhoeus"

class Book
  attr_accessor :book_id, :title, :format, :cover_url, :isbn, :creator_id, :creatorName, :responsible, :rating, :tnr, :lang,
                :work_id, :work_isbn, :review_collection, :same_author_collection, :similar_works_collection, :abstract, :randomized_books

  def initialize(tnr)
    timing_start = Time.now
    timings = "\nSPARQL - get book info: "

    @tnr = tnr
    @rating                   = {} # ratings format {:source, :num_raters, :rating}
    @review_collection        = []
    @same_author_collection   = []
    @similar_works_collection = []

    url      = RESOURCE_PREFIX + tnr.to_s
    @book_id = RDF::URI(url)
    query    = QUERY.select(:title, :format, :isbn, :work_id, :creator_id, :responsible, :abstract, :krydder, :lang)
    query.distinct.from(DEFAULT_GRAPH)
    query.sample(:cover_url, :alt_cover_url, :workAbstract, :workKrydder)
    query.group_digest(:creatorName, ', ', 1000, 1)
    query.where([@book_id, RDF::DC.title, :title],
             [@book_id, RDF::DC.language, :lang],
             [@book_id, RDF::DC.format, :format])
    query.optional([@book_id, RDF::FOAF.depiction, :cover_url])
    query.optional([@book_id, RDF::IFACE.altDepictedBy, :alt_cover_url])
    query.optional([@book_id, RDF::DC.abstract, :abstract])
    query.optional([@book_id, RDF::DEICH.krydder_beskrivelse, :krydder])
    query.optional([@book_id, RDF::BIBO.isbn, :isbn])
    query.optional([@book_id, RDF::DC.creator, :creator_id],
                [:creator_id, RDF::FOAF.name, :creatorName])
    query.optional([@book_id, RDF::RDA.statementOfResponsibility, :responsible])
    query.optional([:work_id, RDF::FABIO.hasManifestation, @book_id])
    query.optional([:work_id, RDF::FABIO.hasManifestation, :book],
                [:book, RDF::DC.abstract, :workAbstract])
    query.optional([:work_id, RDF::FABIO.hasManifestation, :book],
                [:book, RDF::DEICH.krydder_beskrivelse, :workKrydder])


    print "#{query.pp}"
    results       = REPO.select(query)
    timings += "#{Time.now - timing_start} s."
    unless results.empty?
      @title       = results.first[:title]
      @format      = results.first[:format]
      @cover_url   = results.first[:cover_url] || results.first[:alt_cover_url]
      @isbn        = results.first[:isbn].to_s if results.first[:isbn]
      @work_id     = results.first[:work_id] unless results.first[:work_id].to_s.empty?
      @creator_id  = results.first[:creator_id]
      @creatorName = results.first[:creatorName] unless results.first[:creatorName].to_s.empty?
      @responsible = results.first[:responsible]
      @lang        = results.first[:lang]
      unless results.first[:abstract].to_s.empty?
        @abstract  = results.first[:abstract]
      else
        @abstract  = results.first[:workAbstract] unless results.first[:workAbstract].to_s.empty?
      end
      unless results.first[:krydder].to_s.empty?
        @krydder  = results.first[:krydder]
      else
        @krydder  = results.first[:workKrydder] unless results.first[:workKrydder].to_s.empty?
      end

      # fetch isbns for work into array
      if @work_id
        timing_start = Time.now
        timings += "\nSPARQL - get work isbns: "
        query = QUERY.select(:work_isbns)
        query.select.where([@work_id, RDF::BIBO.isbn, :work_isbns])
        #puts "#{query}"
        results     = REPO.select(query)
        timings += "#{Time.now - timing_start} s."
        @work_isbns = results.bindings[:work_isbns].to_a.uniq
      end
      timing_start = Time.now
      timings += "\nSPARQL - get local reviews: "
      fetch_local_reviews
      timings += "#{Time.now - timing_start} s."

      timing_start = Time.now
      timings += "\nSPARQL - same author books: "
      fetch_same_author_books
      timings += "#{Time.now - timing_start} s."

      timing_start = Time.now
      timings += "\nSPARQL - similar works: "
      fetch_similar_works
       timings += "#{Time.now - timing_start} s."

      timing_start = Time.now
      timings += "\nHTTP - get remote data: "
      fetch_remote_data
      timings += "#{Time.now - timing_start} s.\n\n"
      puts timings
      enforce_review_order
    else
      @book_id = nil
    end
  end

  #private

  def enforce_review_order
    # Sorter etter rangeringen i arrayen 'order'
    # kilder som ikke er i 'order' kommer først (i.e alle deichmankildene)

    if @lang == RDF::URI("http://lexvo.org/id/iso639-3/eng")
      order = ["Novelist", "Goodreads", "Ønskebok", "Bokkilden", "Bibliotekbasen", "Katalogkrydder"]
     else
      order = ["Ønskebok", "Novelist", "Bokkilden", "Bibliotekbasen", "Katalogkrydder", "Goodreads"]
    end

    @review_collection.sort! do |a,b|
      (order.index(a[:source]) || -1) <=> (order.index(b[:source]) || -1)
    end

  end

  def fetch_cover_url(book_id = self.book_id)
    # Find alternative cover from optionals:
    # 1. other cover from work in same language
    # 2. any other cover from work
    # or return nil
    query = QUERY.select.sample(:same_language_format_image, :same_language_image, :any_image)
    query.from(DEFAULT_GRAPH)
    query.where([book_id, RDF::DC.language, :lang])
    query.optional([:work, RDF::FABIO.hasManifestation, book_id])
    query.optional([:work, RDF::FABIO.hasManifestation, :same_language_format_book],
           [:same_language_format_book, RDF::DC.language, :lang],
           [:same_language_format_book, RDF::DC.format, self.format],
           [:same_language_format_book, RDF::FOAF.depiction, :same_language_format_image])
    query.optional([:work, RDF::FABIO.hasManifestation, :same_language_book],
           [:same_language_book, RDF::DC.language, :lang],
           [:same_language_book, RDF::FOAF.depiction, :same_language_image])
    query.optional([:work, RDF::FABIO.hasManifestation, :any_book],
           [:any_book, RDF::FOAF.depiction, :any_image],
           [:any_book, RDF::DC.format, self.format])

    puts "#{query.pp}" if ENV['RACK_ENV'] == 'development'

    results = REPO.select(query)

    [results.first[:same_language_format_image],
     results.first[:same_language_image],
     results.first[:any_image]].compact.first
  end

  def fetch_local_reviews(limit=4)
    # her henter vi omtale
    query = QUERY.select(:review_id, :review_title, :review_text, :review_source, :reviewer)
      query.distinct
      query.from(REVIEW_GRAPH)
      query.from_named(DEFAULT_GRAPH)
      if self.work_id
        query.where([self.work_id, RDF::REV::hasReview, :review_id, :context=>DEFAULT_GRAPH])
      else
        query.where([self.book_id, RDF::REV::hasReview, :review_id, :context=>DEFAULT_GRAPH])
      end
      query.where([:review_id, RDF::REV.title, :review_title],
                  [:review_id, RDF::REV.text, :review_text])
      query.optional([:review_id, RDF::DC.source, :source_id],
                     [:source_id, RDF::FOAF.name, :review_source])
      query.optional([:review_id, RDF::REV.reviewer, :reviewer])

    print "#{query.pp}"
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
    @review_collection.push({:text => @abstract.to_s, :source => "Bibliotekbasen"}) if @abstract
    @review_collection.push({:text => @krydder.to_s, :source => "Katalogkrydder"}) if @krydder
    return @review_collection
  end

  def fetch_remote_data
    # for remote in %w[Novelist Bokkilden Goodreads Bokelskere]
    #   #break if @review_collection.size >= 4
    #   self.send(remote.to_sym)
    # end
    hydra = Typhoeus::Hydra.new
    req1 = Typhoeus::Request.new("http://www.goodreads.com/book/isbn", :timeout => 2,
      :params => {:format => 'xml', :key => "wDjpR0GY1xXIqTnx2QL37A",
      :isbn => @isbn})
    req1.on_complete  { |response| Goodreads(response) unless response.timed_out? }
    if SETTINGS['novelist']
      req2 = Typhoeus::Request.new("http://140.234.254.43/Services/SearchService.asmx/Search",
        :timeout => 2, :params => {:prof => SETTINGS['novelist']['profile'],
          :pwd => SETTINGS['novelist']['password'], :db => "noh", :query => @isbn})
      req2.on_complete { |response| Novelist(response) unless response.timed_out? }
    end
    req3 = Typhoeus::Request.new("http://bokelskere.no/api/1.0/boker/info/#{@isbn}/", :timeout => 2)
    req3.on_complete { |response| Bokelskere(response) unless response.timed_out? }

    if @isbn
      hydra.queue req1
      hydra.queue req2 if SETTINGS['novelist']
      hydra.queue req3
      hydra.run
    end
    Bokkilden()
  end

  def Goodreads(result)
    gr_description = nil

    return nil unless result.body
    return nil if result.body =~ /error/
    xml = Nokogiri::XML result.body
    begin
      gr_description = xml.xpath('//description').first.content unless xml.xpath('//description').first.content.strip.empty?
      gr_num_raters = xml.xpath('//ratings_count').first.content.to_i
      gr_rating = xml.xpath('//ratings_sum').first.content.to_i
    rescue NoMethodError
      return nil
    end
    if gr_rating
      @rating[:rating] = gr_rating
      @rating[:num_raters] = gr_num_raters
      @rating[:source] = "Goodreads"
    end
    @review_collection.push({:source => "Goodreads", :text => gr_description}) if gr_description
  end

  def Bokelskere(result)
     # Don't bother with Bokelskere if we have ratings from Goodreads
    return nil if @rating[:rating]

    return nil unless result
    return nil unless result.body
    return nil if result.body.strip.empty?
    return nil if result.body =~ /Not Found/

    jsonres = JSON.parse(result.body)
    if jsonres['antall_terningkast'].to_i > 0
      @rating[:num_raters] = jsonres['antall_terningkast']
      @rating[:rating] = (jsonres['gjennomsnittelig_terningkast'] / 1.2) * @rating[:num_raters]
      @rating[:source] = "Bokelskere"
    end
  end

  def Novelist(result)

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

    bk_ingress = ""

    @work_isbns.each do |isbn|
      res = Typhoeus::Request.get("http://partner.bokkilden.no/SamboWeb/partner.do", :timeout => 2,
        :params => {:format => "XML", :uttrekk => 5, :pid => 0, :ept => 3, :xslId => 117,
              :enkeltsok => isbn})
      if res.body
        xml = Nokogiri::XML res.body
        if xml.xpath('//Ingress').size() >= 1
          bk_ingress = xml.xpath('//Ingress').first.content
        end
        break unless bk_ingress.empty?
      end
    end

    return nil if bk_ingress.empty?
    @review_collection.push({:text => bk_ingress, :source => "Bokkilden"})
  end

  def fetch_same_author_books
    # this query fetches other works by same author
    query = QUERY.select(:similar_work, :lang, :original_language, :format, :book_title, :book)
      query.sample(:cover_url, :alt_cover_url)
      query.distinct
      query.from(DEFAULT_GRAPH)
      query.where(
        [self.book_id, RDF::DC.creator, :creator],
        [:work, RDF::FABIO.hasManifestation, self.book_id],
        [:similar_work, RDF::DC.creator, :creator],
        [:similar_work, RDF::FABIO.hasManifestation, :book],
        [:book, RDF::DC.language, :lang],
        [:book, RDF::DC.title, :book_title],
        [:book, RDF::DC.format, RDF::URI('http://data.deichman.no/format/Book')]
        )
      query.optional([:book, RDF::FOAF.depiction, :cover_url])
      query.optional([:book, RDF::IFACE.altDepictedBy, :alt_cover_url])
      query.optional([:book, RDF::DEICH.originalLanguage, :original_language])
      query.minus([:work, RDF::FABIO.hasManifestation, :book])

    puts query
    puts "#{query.pp}" if ENV['RACK_ENV'] == 'development'
    solutions = REPO.select(query)
    results = select_manifestations(solutions)
    return nil unless results
    @randomized_books = randomize_books(results)
    results.order_by(:book_title)
    results.each do |same_author_books|
    @same_author_collection.push({
      :book => same_author_books[:book],
      :title => same_author_books[:book_title],
      :cover_url => same_author_books[:cover_url] || same_author_books[:alt_cover_url]
      })
    end
  end

  def randomize_books(solutions)
    randomized_books = Marshal.load(Marshal.dump(solutions)).shuffle
    results = []
    randomized_books.each { |book| results << book if book[:cover_url] }
    randomized_books.each { |book| results << book unless book[:cover_url] }
    results
  end


  def fetch_similar_works
    # this query fetches related books
    similaritygraph = {:context => RDF::URI('http://data.deichman.no/noeSomLigner')}
    bookgraph       = {:context => RDF::URI("http://data.deichman.no/books")}

    query = QUERY.select(:book, :book_title, :lang, :original_language, :format, :similar_work)
    query.sample(:cover_url, :alt_cover_url)
    query.group_digest(:creatorName, ', ', 1000, 1)
    query.distinct
    query.from(DEFAULT_GRAPH)
    query.from_named(SIMILARITY_GRAPH)
    query.where(
        [:work, RDF::FABIO.hasManifestation, book_id],
        [:work, RDF::DC.creator, :creator],
        [:work, :predicate, :similar_work, :context => SIMILARITY_GRAPH],
        [:similar_work, RDF::FABIO.hasManifestation, :book],
        [:book, RDF::DC.title, :book_title],
        [:book, RDF::DC.language, :lang],
        [:book, RDF::DC.format, :format]
        )
    query.optional([:book, RDF::FOAF.depiction, :cover_url])
    query.optional([:book, RDF::IFACE.altDepictedBy, :alt_cover_url])
    query.optional([:book, RDF::DEICH.originalLanguage, :original_language])
    query.optional([:book, RDF::DC.creator, :similar_book_creator],
        [:similar_book_creator, RDF::FOAF.name, :creatorName])
    query.minus([:similar_work, RDF::DC.creator, :creator])

    #puts query
    puts "#{query.pp}" if ENV['RACK_ENV'] == 'development'
    solutions = REPO.select(query)
    results = select_manifestations(solutions)

    return nil unless results

    results.each do |similar_book|
      @similar_works_collection.push({
        :book => similar_book[:book],
        :title => similar_book[:book_title],
        :cover_url => similar_book[:cover_url] || similar_book[:alt_cover_url],
        :creatorName => similar_book[:creatorName]
        })
    end
  end

  def select_manifestations(solutions)
    return nil if solutions.empty?

    results = RDF::Query::Solutions.new
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
            if s[:format] == RDF::URI("http://data.deichman.no/format/Book")
              if s[:lang] == RDF::URI("http://lexvo.org/id/iso639-3/nob") || s[:lang] == RDF::URI("http://lexvo.org/id/iso639-3/nno")
                results << s
                throw :found_book
              end
            end
          end
        end
        solutions.each do |s|
          if ds[:similar_work] == s[:similar_work]
            if s[:format] == RDF::URI("http://data.deichman.no/format/Book")
              unless s[:original_language]
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
        solutions.each do |s|
          if ds[:similar_work] == s[:similar_work]
            if s[:format] == RDF::URI("http://data.deichman.no/format/Book")
              if s[:lang] == RDF::URI("http://lexvo.org/id/iso639-3/eng") ||
                s[:lang] == RDF::URI("http://lexvo.org/id/iso639-3/swe") ||
                s[:lang] == RDF::URI("http://lexvo.org/id/iso639-3/dan")
                throw :found_book
              end
            end
          end
        end
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
            unless s[:original_language]
              if s[:lang] == RDF::URI("http://lexvo.org/id/iso639-3/eng") ||
                s[:lang] == RDF::URI("http://lexvo.org/id/iso639-3/swe") ||
                s[:lang] == RDF::URI("http://lexvo.org/id/iso639-3/dan")
                results << s
                throw :found_book
              end
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
