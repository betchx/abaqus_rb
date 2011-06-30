
unless defined?(ABAQUS_MPC_RB)
  ABAQUS_MPC_RB=true
  dir = File::dirname(__FILE__)
  require dir + '/inp'
  module Abaqus
    class MPC
      extend Inp
      @@all = {}
      def self.parse(head, body)
        key, opts = parse_command(head)
        unless key == "*MPC"
          raise ArgumentError,"wrong keyword was given (#{key})"
        end
        list = []
        command = parse_data(body) do |line|
          list << self.new(*line.split(/\s*,\s*/))
        end
        return command, list
      end
      def self.clear
        @@all.clear
      end
      def self.size
        @@all.size
      end
      def self.[](nid)
        @@all[nid]
      end
      def initialize(mpc_type, dependent_node, independent_node)
        @independent_node = independent_node.to_i
        @dependent_node = dependent_node.to_i
        @mpc_type = mpc_type.upcase
        @@all[@dependent_node] = self
      end
      attr_reader :independent_node, :dependent_node, :mpc_type
      alias :dep :dependent_node
      alias :ind :independent_node
      alias :type :mpc_type

      def self.independent_nodes
        @@all.values.map{|x| x.ind}.sort.uniq
      end
      def self.dependent_nodes(nid = nil)
        if nid
          @@all.keys.select{|x| @@all[x].ind == nid}.sort
        else
          @@all.keys.sort
        end
      end
      def self.inds
        self.independent_nodes
      end
      def self.deps(nid = nil)
        self.dependent_nodes(nid)
      end
    end
  end
end

if $0 == __FILE__
  require 'test/unit'
  require 'flexmock/test_unit'

  class TestMPC < Test::Unit::TestCase
    def setup
      @ind = 3
      @dep = 6
      @type = "beam"
      @mpc = Abaqus::MPC.new(@type, @dep, @ind)
    end
    def teardown
      Abaqus::MPC.clear
    end
    def test_type
      assert_equal(@type.upcase, @mpc.type)
    end
    def test_ind
      assert_equal(@ind, @mpc.ind)
    end
    def test_dep
      assert_equal(@dep, @mpc.dep)
    end
  end
  class TestMPCParse < Test::Unit::TestCase
    def teardown
      Abaqus::MPC.clear
    end
    def setup
      @mock = flexmock
      @mock.should_receive(:gets).at_most.times(4).and_return(
        "BEAM, 2, 1",
        "link, 3, 1\n",
        "BEAM, 4, 6\r\n",
        "*DUMMY\n",
        nil
      )
      Abaqus::MPC.parse("*MPC",@mock)
    end
    def test_deps
      assert_equal(2, Abaqus::MPC[2].dep)
      assert_equal(3, Abaqus::MPC[3].dep)
      assert_equal(4, Abaqus::MPC[4].dep)
    end
    def test_independent
      assert_equal(1, Abaqus::MPC[2].ind)
      assert_equal(1, Abaqus::MPC[3].ind)
      assert_equal(6, Abaqus::MPC[4].ind)
    end
    def test_size
      assert_equal(3, Abaqus::MPC.size)
    end
    def test_type
      assert_equal("BEAM", Abaqus::MPC[2].type)
      assert_equal("LINK", Abaqus::MPC[3].type)
      assert_equal("BEAM", Abaqus::MPC[4].type)
    end
    def test_deps
      assert_equal([2,3,4], Abaqus::MPC.deps)
    end
    def test_dependent_nodes
      assert_equal([2,3,4], Abaqus::MPC.dependent_nodes)
    end
    def test_deps_with_arg
      assert_equal([2,3], Abaqus::MPC.deps(1))
    end
    def test_inds
      assert_equal([1,6], Abaqus::MPC.inds)
    end
    def test_independent_nodes
      assert_equal([1,6], Abaqus::MPC.independent_nodes)
    end
  end
end

