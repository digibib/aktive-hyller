#encoding: utf-8
require "rubygems"
require "bundler/setup"
require "rdf"
require "rdf/virtuoso"
require "sinatra/r18n" # internationalization

# read configuration file
SETTINGS = YAML::load(File.open(File.join('config', 'settings.yml')))

# Global constants
REPO            = RDF::Virtuoso::Repository.new(SETTINGS["sparql_endpoint"])
DEFAULT_GRAPH   = RDF::URI(SETTINGS["default_graph"])
RESOURCE_PREFIX = RDF::URI(SETTINGS["resource_prefix"])
QUERY           = RDF::Virtuoso::Query

# load all library files
Dir[File.dirname(__FILE__) + '/../lib/*.rb'].each do |file|
  require file
end

R18n::I18n.default = 'nb'
R18n.default_places { File.join('config', 'locales') }
R18n.set
