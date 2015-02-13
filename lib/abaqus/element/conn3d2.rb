unless defined?(ABAQUS_ELEMENT_CONN3D2_RB)
  ABAQUS_ELEMENT_CONN3D2_RB = true

  require 'abaqus/element_base'

  class Abaqus::Element::CONN3D2 < Abaqus::Element
    def initialize(i,n1,n2=nil)
      @nodes = [n1, n2]
      @i = i
      assign(@i,self)
    end
    attr_reader :i
    def [](n)
      @nodes[n]
    end
    def type
      "CONN3D2"
    end
    attr_reader :nodes
    def self.parse_line(line)
      i, n1, n2, n3 = * line.split(/,/)
      if n3
        raise ParseError, "Too many nodes were given"
      end
      unless n1
        raise ParseError, "Too few nodes were ginev"
      end
      return i, n1, n2
    end
    def self.parse(line, io)
      self.new(*parse_line(line).map{|x| x.to_i})
    end
    Abaqus::Element::BasicElementMap << [/CONN3D2/,self]
  end
end

