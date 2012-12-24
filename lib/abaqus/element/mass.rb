
unless defined?(ABAQUS_ELEMENT_MASS_RB)
  ABAQUS_ELEMENT_MASS_RB = true

  require 'abaqus/element_base'

  class Abaqus::Element::MASS < Abaqus::Element
    def initialize(i,n1)
      @nodes = [n1]
      @i = i
      assign(@i,self)
    end
    attr_reader :i
    def [](n)
      @nodes[n]
    end
    def type
      "MASS"
    end
    attr_reader :nodes
    def self.parse_line(line)
      i, n1, n2 = * line.split(/,/)
      if n2
        raise ParseError, "Too many nodes were given"
      end
      unless n1
        raise ParseError, "No nodes were given"
      end
      return i, n1
    end
    def self.parse(line, io)
      self.new(*parse_line(line).map{|x| x.to_i})
    end
    Abaqus::Element::BasicElementMap << [/MASS/,self]
  end
end

###############################################################

if $0 == __FILE__
  require 'test/unit'
  require 'flexmock/test_unit'
  class TestElementMASS < Test::Unit::TestCase
    def setup
      @eid = 3
      @nids = [4]
      @e = Abaqus::Element.new("MASS",@eid, *@nids)
    end
    def teardown
      Abaqus::Element.clear
    end
    def test_id
      assert_equal(@eid, @e.i)
    end
    def test_nids
      assert_equal(@nids, @e.nodes)
    end
    def test_type
      assert_equal("MASS", @e.type)
    end
  end
end
