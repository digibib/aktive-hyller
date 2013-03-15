require 'rdf'

# Extend module RDF with vocabularies we need to use
# NB: inherited method :name must be overridden if used as property (eg. RDF::XFOAF.name)

module RDF
  class BIBO < RDF::Vocabulary("http://purl.org/ontology/bibo/");end
  class RDFS < RDF::Vocabulary("http://www.w3.org/2000/01/rdf-schema#");end
  class XFOAF < RDF::Vocabulary("http://www.foafrealm.org/xfoaf/0.1/")
    property :name
  end
  class LEXVO < RDF::Vocabulary("http://lexvo.org/ontology#")
    property :name
  end
  class DEICH < RDF::Vocabulary("http://data.deichman.no/");end
  class IFACE < RDF::Vocabulary("http://www.multimedian.nl/projects/n9c/interface#");end
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

# monkey-patch Virtuoso gem for pretty printing to logs
module RDF::Virtuoso
  class Query
    def pp
      self.to_s.gsub(/(SELECT|FROM|WHERE|GRAPH|FILTER)/,"\n"+'\1').gsub(/(\s\.\s|WHERE\s{\s|})(?!})/, '\1'+"\n")
    end
  end
end
