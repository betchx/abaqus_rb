unless defined?(ABAQUS_ELEMENT_R3D4_RB)
  ABAQUS_ELEMENT_R3D4_RB = true

  require 'abaqus/element_base'

  class Abaqus::Element::R3D4 < Abaqus::Element
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
      "R3D4"
    end
    attr_reader :nodes
    def self.parse_line(line)
      line.split(/,/)
    end
    def self.parse(line, io)
      self.new(*parse_line(line).map{|x| x.to_i})
    end
    Abaqus::Element::BasicElementMap << [/R3D4/,self]
  end
end
