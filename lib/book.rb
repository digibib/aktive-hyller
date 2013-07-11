# encoding: UTF-8
require "rdf/virtuoso"
require "nokogiri"
require "faraday"
require "typhoeus"

Book   = Struct.new(:book_id, :title, :format, :cover_url, :isbn, :authors, :responsible, :rating, :tnr, :lang, :work_tnrs, :book_on_shelf,
                :work_id, :work_isbns, :review_collection, :same_author_collection, :similar_works_collection, :abstract, :krydder, :randomized_books)

# Hash to struct method
class Hash
  def to_struct(name)
    cls = Struct.const_get(name) rescue Struct.new(name, *keys)
    struct = cls.new
    struct.members.each {|k| struct[k] = self[k.to_s]}
    struct
  end
end

class Book
#  attr_accessor :book_id, :title, :format, :cover_url, :isbn, :creator_id, :creatorName, :responsible, :rating, :tnr, :lang,
#                :work_id, :work_isbns, :review_collection, :same_author_collection, :similar_works_collection, :abstract, :randomized_books

  def initialize
    self.rating                   = {} # ratings format {:source, :num_raters, :rating}
    self.review_collection        = []
    self.same_author_collection   = []
    self.similar_works_collection = []
    self.authors = []
  end

  def find(tnr)
    timing_start = Time.now
    timings = "\nSPARQL - get book info: "

    self.tnr = tnr

    url      = RESOURCE_PREFIX + tnr.to_s
    self.book_id = RDF::URI(url)
    query    = QUERY.select(:title, :format, :isbn, :work_id, :creatorName, :creator_id, :responsible, :abstract, :krydder, :lang)
    query.distinct.from(DEFAULT_GRAPH)
    # sample stops after first hit
    query.sample(:cover_url, :alt_cover_url, :workAbstract, :workKrydder)
    query.where([self.book_id, RDF::DC.title, :title],
             [self.book_id, RDF::DC.language, :lang],
             [self.book_id, RDF::DC.format, :format])
    query.optional([self.book_id, RDF::FOAF.depiction, :cover_url])
    query.optional([self.book_id, RDF::IFACE.altDepictedBy, :alt_cover_url])
    query.optional([self.book_id, RDF::DC.abstract, :abstract])
    query.optional([self.book_id, RDF::DEICH.krydder_beskrivelse, :krydder])
    query.optional([self.book_id, RDF::BIBO.isbn, :isbn])
    query.optional([self.book_id, RDF::DC.creator, :creator_id],
                [:creator_id, RDF::FOAF.name, :creatorName])
    query.optional([self.book_id, RDF::RDA.statementOfResponsibility, :responsible])
    query.optional([:work_id, RDF::FABIO.hasManifestation, self.book_id])
    query.optional([:work_id, RDF::FABIO.hasManifestation, :book],
                [:book, RDF::DC.abstract, :workAbstract])
    query.optional([:work_id, RDF::FABIO.hasManifestation, :book],
                [:book, RDF::DEICH.krydder_beskrivelse, :workKrydder])


    print "#{query.pp}"
    solutions = REPO.select(query)
    timings += "#{Time.now - timing_start} s."
    unless solutions.empty?
      books = cluster(solutions, :binding => "work_id")

      # populate self with book
      to_self(books.first)
=begin
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
=end
      if self.work_id
        timing_start = Time.now
        timings += "\nSPARQL - get work isbns & titlenrs: "
        query = QUERY.select(:work_isbns, :work_tnr)
        query.select.where([self.work_id, RDF::BIBO.isbn, :work_isbns])
        query.where([self.work_id, RDF::FABIO.hasManifestation, :work_tnr],
                           [self.book_id, RDF::DC.language, :language])
        query.filter("?language = <http://lexvo.org/id/iso639-3/dan> || ?language = <http://lexvo.org/id/iso639-3/nob> || ?language = <http://lexvo.org/id/iso639-3/nno> || ?language = <http://lexvo.org/id/iso639-3/swe> || ?language = <http://lexvo.org/id/iso639-3/eng>")
        results     = REPO.select(query)
        timings += "#{Time.now - timing_start} s."
        self.work_isbns = results.bindings[:work_isbns].to_a.uniq
        self.work_tnrs = results.bindings[:work_tnr].to_a.uniq.map { |s| s.to_s[/[\d]*$/,0] }
        #puts "num isbn: #{self.work_isbns.count}\nnum titlenr: #{self.work_tnrs.count}"
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
      timings += "#{Time.now - timing_start} s."
      timing_start = Time.now
      timings += "\nHTTP - get eksemplarstatus: "
      fetch_book_status
      timings += "#{Time.now - timing_start} s.\n\n"
      puts timings
      #puts "på hylla: #{self.book_on_shelf}"
      enforce_review_order
      return self
    else
      self.book_id = nil
    end
  end

  #private

  # This method clusters solutions on binding
  # params:
  #   :binding => binding to cluster
  def cluster(solutions, params)
    return solutions unless params[:binding]
    binding = params[:binding].to_sym
    books = RDF::Query::Solutions.new
      # make a clone of distinct works first
      distinct = Marshal.load(Marshal.dump(solutions)).select(binding).distinct
      distinct.each do |d|
        # make sure distinct filter is run on Marshal clone of solutions before populating
        cluster = Marshal.load(Marshal.dump(solutions)).filter {|solution| solution[binding] == d[binding] }
        #puts cluster.inspect
        # populate one book or array of books
        books << populate_book(cluster)
      end
    books
  end

  # populates self book class or array of books from cluster and add Authors
  def populate_book(cluster)
    # first populate self from first result in cluster
    book = Book.new
    book.members.each {|name| book[name] = cluster.first[name] unless cluster.first[name].nil? }
    book.cover_url = cluster.first[:cover_url] ? cluster.first[:cover_url] : cluster.first[:alt_cover_url]  # pick work cover_url if no cover on manifestation
    book.abstract  = cluster.first[:workAbstract] unless book.abstract                                      # pick workAbstrack if abstract not found
    book.krydder   = cluster.first[:krydder] ? cluster.first[:krydder] : cluster.first[:workKrydder]        # pick workKrydder if krydder not found
    # here comes clustering
    authors = []
    cluster.each do |s|
      # self.authors << Author.new(s[:creator_id], s[:creatorName]) unless self.authors.find {|a| a[:creator_id] == s[:creator_id] }
      # for now we only need Author's name
      authors << s[:creatorName] unless authors.find {|a| a == s[:creatorName] }
    end
    # make comma separated author
    book.authors = authors.join(', ')
    book
  end

  def to_self(book)
    self.members.each {|name| self[name] = book[name] unless book[name].nil?}
  end

  def enforce_review_order
    # Sorter etter rangeringen i arrayen 'order'
    # kilder som ikke er i 'order' kommer først (i.e bokanbefalingsbasen -Ønskebok)

    if self.lang == RDF::URI("http://lexvo.org/id/iso639-3/eng")
      order = ["Novelist", "Goodreads", "Bokanbefalingsbasen", "Ønskebok", "Bokkilden", "Bibliotekbasen", "Katalogkrydder"]
     else
      order = ["Ønskebok", "Novelist", "Bokkilden", "Bibliotekbasen", "Katalogkrydder", "Goodreads"]
    end

    self.review_collection.sort! do |a,b|
      (order.index(a[:sort_source]) || -1) <=> (order.index(b[:sort_source]) || -1)
    end

  end

  def fetch_book_status
    # check in settings if book holding should be checked
    unless Array(SETTINGS['book_on_shelf']).empty?
      res = Typhoeus.get("#{SETTINGS['book_status_api']}#{self.work_tnrs.join(',')} fields=simple loc=#{SETTINGS['book_on_shelf'].join(':')}")
      res = JSON.parse(res.response_body)
      if res["elements"].select { |k,v| v["available"] > 0 }.empty?
        self.book_on_shelf = "out"
      else
        self.book_on_shelf = "in"
      end
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
      query.from_named(SOURCES_GRAPH)
      if self.work_id
        query.where([self.work_id, RDF::REV::hasReview, :review_id, :context=>DEFAULT_GRAPH])
      else
        query.where([self.book_id, RDF::REV::hasReview, :review_id, :context=>DEFAULT_GRAPH])
      end
      query.where([:review_id, RDF::REV.title, :review_title],
                  [:review_id, RDF::REV.text, :review_text],
                  [:review_id, RDF::DC.issued, :issued])
      query.optional([:review_id, RDF::DC.source, :source_id],
                     [:source_id, RDF::FOAF.name, :review_source, :context=>SOURCES_GRAPH])
      query.optional([:review_id, RDF::REV.reviewer, :reviewer])

    print "#{query.pp}"
    reviews = REPO.select(query)
    # reviews is a graph RDF object, RDF::Query::Solutions
    # http://rdf.rubyforge.org/RDF/Query/Solutions.html
    # can use filter, count, offset, limit, distinct, etc. as on a SPARQL QUERY
    # can also be iterated as RDF::Query::Solution with bindings from query
    reviews.limit(limit) if limit
    for r in reviews
      unless r[:review_source].to_s == "Ønskebok"
        self.review_collection.push({:title => r[:review_title].to_s, :text => r[:review_text].to_s,
        :source => r[:review_source].to_s, :sort_source => "Bokanbefalingsbasen"})
      else
        self.review_collection.push({:title => r[:review_title].to_s, :text => r[:review_text].to_s,
        :source => r[:review_source].to_s, :sort_source => r[:review_source].to_s})
      end
    end
    self.review_collection.push({:text => self.abstract.to_s, :source => "Bibliotekbasen", :sort_source => "Bibliotekbasen"}) if self.abstract
    self.review_collection.push({:text => self.krydder.to_s, :source => "Katalogkrydder", :sort_source => "Katalogkrydder"}) if self.krydder
    return self.review_collection
  end

  def fetch_remote_data
    # for remote in %w[Novelist Bokkilden Goodreads Bokelskere]
    #   #break if @review_collection.size >= 4
    #   self.send(remote.to_sym)
    # end
    english_isbn = self.work_isbns.select { |isbn| isbn.to_s.match(/^0|^9780/) }.first || self.work_isbns.first.to_s
    hydra = Typhoeus::Hydra.new
    req1 = Typhoeus::Request.new("http://www.goodreads.com/book/isbn", :timeout => 2,
      :params => {:format => 'xml', :key => "wDjpR0GY1xXIqTnx2QL37A",
      :isbn => english_isbn})
    req1.on_complete  { |response| Goodreads(response) unless response.timed_out? }
    if SETTINGS['novelist']
      req2 = Typhoeus::Request.new("http://140.234.254.43/Services/SearchService.asmx/Search",
        :timeout => 2, :params => {:prof => SETTINGS['novelist']['profile'],
          :pwd => SETTINGS['novelist']['password'], :db => "noh", :query => english_isbn})
      req2.on_complete { |response| Novelist(response) unless response.timed_out? }
    end
    req3 = Typhoeus::Request.new("http://bokelskere.no/api/1.0/boker/info/#{self.isbn}/", :timeout => 2)
    req3.on_complete { |response| Bokelskere(response) unless response.timed_out? }

    if self.isbn
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
      self.rating[:rating] = gr_rating
      self.rating[:num_raters] = gr_num_raters
      self.rating[:source] = "Goodreads"
    end
    self.review_collection.push({:source => "Goodreads", :sort_source => "Goodreads", :text => gr_description}) if gr_description
  end

  def Bokelskere(result)
     # Don't bother with Bokelskere if we have ratings from Goodreads
    return nil if self.rating[:rating]

    return nil unless result
    return nil unless result.body
    return nil if result.body.strip.empty?
    return nil if result.body =~ /Not Found/

    jsonres = JSON.parse(result.body)
    if jsonres['antall_terningkast'].to_i > 0
      self.rating[:num_raters] = jsonres['antall_terningkast']
      self.rating[:rating] = (jsonres['gjennomsnittelig_terningkast'] / 1.2) * self.rating[:num_raters]
      self.rating[:source] = "Bokelskere"
    end
  end

  def Novelist(result)

    return nil if result.nil?

    xml = Nokogiri::XML result.body
    if xml.xpath('//ab').size() >= 1
      nl_description = xml.xpath('//ab').first.content
    end

    return nil unless nl_description
    self.review_collection.push({:source => "Novelist", :sort_source => "Novelist", :text => nl_description})
  end

  def Bokkilden
    self.work_isbns = [self.isbn] unless self.work_isbns
    return nil if self.work_isbns.empty?

    bk_ingress = ""

    self.work_isbns.each do |isbn|
      res = Typhoeus::Request.get("http://partner.bokkilden.no/SamboWeb/partner.do", :timeout => 2,
        :params => {:format => "XML", :uttrekk => 5, :pid => 0, :ept => 3, :xslId => 117,
              :enkeltsok => isbn.to_s})
      if res.body
        xml = Nokogiri::XML res.body
        if xml.xpath('//Ingress').size() >= 1
          bk_ingress = xml.xpath('//Ingress').first.content
        end
        break unless bk_ingress.empty?
      end
    end

    return nil if bk_ingress.empty?
    self.review_collection.push({:text => bk_ingress, :source => "Bokkilden", :sort_source => "Bokkilden"})
  end

  def fetch_same_author_books
    # this query fetches other works by same author
    query = QUERY.select(:similar_work, :lang, :original_language, :title, :book_id)
      query.sample(:cover_url, :alt_cover_url)
      query.distinct
      query.from(DEFAULT_GRAPH)
      query.where(
        [self.book_id, RDF::DC.creator, :creator],
        [:work, RDF::FABIO.hasManifestation, self.book_id],
        [:similar_work, RDF::DC.creator, :creator],
        [:similar_work, RDF::FABIO.hasManifestation, :book_id],
        [:book_id, RDF::DC.language, :lang],
        [:book_id, RDF::DC.title, :title],
        [:book_id, RDF::DC.format, RDF::URI('http://data.deichman.no/format/Book')]
        )
      query.optional([:book_id, RDF::FOAF.depiction, :cover_url])
      query.optional([:book_id, RDF::IFACE.altDepictedBy, :alt_cover_url])
      query.optional([:book_id, RDF::DEICH.originalLanguage, :original_language])
      query.minus([:work, RDF::FABIO.hasManifestation, :book_id])

    #puts query
    puts "#{query.pp}" if ENV['RACK_ENV'] == 'development'
    solutions = REPO.select(query)
    return nil if solutions.empty?
    # choose manifestations
    results = select_manifestations(solutions)
    return nil unless results

    results.order_by(:title)
    # cluster on similar work
    books = cluster(results, :binding => "similar_work")
    # make an initial randomization
    self.randomized_books = randomize_books(results)
=begin
    results.each do |same_author_books|
    self.same_author_collection.push({
      :book => same_author_books[:book],
      :title => same_author_books[:book_title],
      :cover_url => same_author_books[:cover_url] || same_author_books[:alt_cover_url]
      })
    end
=end
    books.each {|b| self.same_author_collection << b}

  end

  # this method randomizes solutions and puts all results with coverart first
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

    query = QUERY.select(:book_id, :title, :lang, :creatorName, :creator_id, :original_language, :format, :similar_work)
    query.sample(:cover_url, :alt_cover_url)
    #query.group_digest(:creatorName, ', ', 1000, 1)
    query.distinct
    query.from(DEFAULT_GRAPH)
    query.from_named(SIMILARITY_GRAPH)
    query.where(
        [:work, RDF::FABIO.hasManifestation, book_id],
        [:work, RDF::DC.creator, :creator_id],
        [:work, RDF::DEICH.similarWork, :similar_work, :context => SIMILARITY_GRAPH],
        [:similar_work, RDF::FABIO.hasManifestation, :book_id],
        [:book_id, RDF::DC.title, :title],
        [:book_id, RDF::DC.language, :lang],
        [:book_id, RDF::DC.format, :format]
        )
    query.optional([:book_id, RDF::FOAF.depiction, :cover_url])
    query.optional([:book_id, RDF::IFACE.altDepictedBy, :alt_cover_url])
    query.optional([:book_id, RDF::DEICH.originalLanguage, :original_language])
    query.optional([:book_id, RDF::DC.creator, :similar_book_creator],
        [:similar_book_creator, RDF::FOAF.name, :creatorName])
    query.minus([:similar_work, RDF::DC.creator, :creator_id])

    #puts query
    puts "#{query.pp}" if ENV['RACK_ENV'] == 'development'
    solutions = REPO.select(query)
    results = select_manifestations(solutions)

    if results 
      books = cluster(results, :binding => "similar_work")
      books.each {|b| self.similar_works_collection << b}
    end
=begin
    books.each do |similar_book|
      self.similar_works_collection.push({
        :book => similar_book[:book_id],
        :title => similar_book[:title],
        :cover_url => similar_book[:cover_url],
        :creatorName => similar_book[:authors]
        })
    end
=end

    #query for autogenerated similarities

    query = QUERY.select(:book_id, :title, :lang, :creatorName, :creator_id, :original_language, :format, :similar_work)
    query.sample(:cover_url, :alt_cover_url)
    #query.group_digest(:creatorName, ', ', 1000, 1)
    query.distinct
    query.from(DEFAULT_GRAPH)
    query.from_named(SIMILARITY_GRAPH)
    query.where(
        [:work, RDF::FABIO.hasManifestation, book_id],
        [:work, RDF::DC.creator, :creator_id],
        [:work, RDF::DEICH.autoGeneratedSimilarity, :similar_work, :context => SIMILARITY_GRAPH],
        [:similar_work, RDF::FABIO.hasManifestation, :book_id],
        [:book_id, RDF::DC.title, :title],
        [:book_id, RDF::DC.language, :lang],
        [:book_id, RDF::DC.format, :format]
        )
    query.optional([:book_id, RDF::FOAF.depiction, :cover_url])
    query.optional([:book_id, RDF::IFACE.altDepictedBy, :alt_cover_url])
    query.optional([:book_id, RDF::DEICH.originalLanguage, :original_language])
    query.optional([:book_id, RDF::DC.creator, :similar_book_creator],
        [:similar_book_creator, RDF::FOAF.name, :creatorName])
    query.minus([:similar_work, RDF::DC.creator, :creator_id])

    puts query
    puts "#{query.pp}" if ENV['RACK_ENV'] == 'development'
    solutions = REPO.select(query)
    results = select_manifestations(solutions)
    
    if results 
      books = cluster(results, :binding => "similar_work")
      books.each {|b| self.similar_works_collection << b}
    end
=begin
    books.each do |similar_book|
      self.similar_works_collection.push({
        :book => similar_book[:book_id],
        :title => similar_book[:title],
        :cover_url => similar_book[:cover_url],
        :creatorName => similar_book[:authors]
        })
    end
=end
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
    distinct_works = Marshal.load(Marshal.dump(solutions)).select(:similar_work).distinct.limit(30)

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
