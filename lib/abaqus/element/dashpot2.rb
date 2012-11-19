unless defined?(ABAQUS_ELEMENT_SPRING2_RB)
  ABAQUS_ELEMENT_DASHPOT2_RB = true

  require 'abaqus/element_base'

  class Abaqus::Element::Dashpot2 < Abaqus::Element
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
      "Dashpot2"
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
    Abaqus::Element::BasicElementMap << [/DASHPOT2/,self]
  end
end

###############################################################

if $0 == __FILE__
  require 'test/unit'
  require 'flexmock/test_unit'
  class TestElementDashpot2 < Test::Unit::TestCase
    def setup
      @eid = 3
      @nids = [4, 6]
      @e = Abaqus::Element.new("Dashpot2",@eid, *@nids)
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
      assert_equal("Dashpot2", @e.type)
    end
  end
end
