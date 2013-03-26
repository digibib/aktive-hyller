#encoding: utf-8
require "rubygems"
require "bundler/setup"
require "rdf"
require "rdf/virtuoso"
require "sinatra/r18n" # internationalization
require "net/smtp"

# read configuration file
SETTINGS = YAML::load(File.open(File.join('config', 'settings.yml')))

# Global constants
REPO             = RDF::Virtuoso::Repository.new(SETTINGS["sparql_endpoint"])
DEFAULT_GRAPH    = RDF::URI(SETTINGS["default_graph"])
SIMILARITY_GRAPH = RDF::URI(SETTINGS["similarity_graph"])
RESOURCE_PREFIX  = RDF::URI(SETTINGS["resource_prefix"])
REVIEW_GRAPH     = RDF::URI('http://data.deichman.no/reviews')
QUERY            = RDF::Virtuoso::Query

# load all library files
Dir[File.dirname(__FILE__) + '/../lib/*.rb'].each do |file|
  require file
end

R18n::I18n.default = 'nb'
R18n.default_places { File.join('config', 'locales') }

def send_error_report(to, message, opts={})
  %x[DISPLAY=#{SETTINGS["error_report"]["display"]} ; /usr/bin/scrot -q 50 /tmp/screenshot.png ]
  screenshot = Base64.encode64 File.open('/tmp/screenshot.png', "rb").read
  
  marker = "AUNIQUEMARKERFROMTHEABYSS"
  opts[:from]        ||= 'digitalutvikling@gmail.com'
  opts[:from_alias]  ||= "Digital Deichman"
  opts[:subject]     ||= "Aktive hyller statistikkrapport"
  
  msg = <<END_OF_MESSAGE
From: #{opts[:from_alias]} <#{opts[:from]}>
To: <#{to}>
Subject: #{opts[:subject]}
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=#{marker}

--#{marker}
Content-type: text/plain; charset=UTF-8
Content-Transfer-Encoding:8bit

#{message}
--#{marker}
Content-Type: image/png; name=screenshot.png
Content-Transfer-Encoding:base64
Content-Disposition: attachment; filename=screenshot.png

#{screenshot}
--#{marker}
END_OF_MESSAGE
  
  
  smtp = Net::SMTP.new(SETTINGS["smtp"]["host"], SETTINGS["smtp"]["port"])
  smtp.enable_starttls if SETTINGS["smtp"]["starttls"]
  smtp.start(SETTINGS["smtp"]["domain"], SETTINGS["smtp"]["username"], SETTINGS["smtp"]["password"], SETTINGS["smtp"]["authentication"]) do
    smtp.send_message msg, opts[:from], to
  end
end
