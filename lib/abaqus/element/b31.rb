unless defined?(ABAQUS_ELEMENT_B31_RB)
  ABAQUS_ELEMENT_B31_RB = true

  #require File::dirname(__FILE__)+"/base" unless defined?(Abaqus::Element)
  require 'abaqus/element/base'

  class Abaqus::Element::B31 < Abaqus::Element
    def initialize(i,n1,n2)
      @nodes = [n1, n2]
      @i = i
      assign(@i,self)
    end
    attr_reader :i
    def [](n)
      @nodes[n]
    end
    def type
      "B31"
    end
    attr_reader :nodes
    def self.parse_line(line)
      i, n1, n2, n3 = * line.split(/,/)
      if n3
        raise ParseError, "Too many nodes were given"
      end
      unless n2
        raise ParseError, "Too few nodes were ginev"
      end
      return i, n1, n2
    end
    def self.parse(line, io)
      self.new(*parse_line(line).map{|x| x.to_i})
    end
  end
end

###############################################################

if $0 == __FILE__
  require 'test/unit'
  require 'flexmock/test_unit'
  class TestElementB31 < Test::Unit::TestCase
    def setup
      @eid = 3
      @nids = [4, 6]
      @e = Abaqus::Element.new("B31",@eid, *@nids)
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
      assert_equal("B31", @e.type)
    end
  end
end
