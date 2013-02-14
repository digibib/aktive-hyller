#encoding: utf-8
require "rubygems"
require "bundler/setup"
require "rdf"
require "rdf/virtuoso"

# read configuration file 
config = YAML::load(File.open(File.join('config', 'repository.yml')))
              
# Global constants
REPO          = RDF::Virtuoso::Repository.new(config["sparql_endpoint"])
DEFAULT_GRAPH = RDF::URI(config["deafult_graph"])
QUERY         = RDF::Virtuoso::Query

# load all library files
Dir[File.dirname(__FILE__) + '/../lib/*.rb'].each do |file|
  require file
end
