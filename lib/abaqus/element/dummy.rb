unless defined?(ABAQUS_ELEMENT_DUMMY_RB)
  ABAQUS_ELEMENT_DUMMY_RB = true

  require 'abaqus/element_base'

  class Abaqus::Element::Dummy < Abaqus::Element
    def initialize(i,*n)
      @nodes = n
      @i = i
      assign(i,self)
    end
    attr_reader :i
    def [](n)
      @nodes[n]
    end
    def type
      "DUMMY"
    end
    attr_reader :nodes
    def self.parse_line(line)
      line.split(/,/)
    end
    def self.parse(line, io)
      self.new(*parse_line(line).map{|x| x.to_i})
    end
    Abaqus::Element::BasicElementMap << [/DUMMY/,self]
  end
end
