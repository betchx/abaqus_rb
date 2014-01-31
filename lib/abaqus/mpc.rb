
unless defined?(ABAQUS_MPC_RB)
  ABAQUS_MPC_RB=true
  dir = 'abaqus' #File::dirname(__FILE__)
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
        @@all[:all].size
      end
      def nodes
        @nodes
      end
      def self.[](i)
        @@all[:all][i]
      end
      def self.select(a,b=nil)
        case a
        when String
          type = a
          if b
            @@all[type].select{|m| m.deps.include?(dep)}
          end
          @@all[type]
        when Integer
          @@all.values.flatten.select{|m| m.nodes.include?(nid.to_s)}
        end
      end
      def initialize(mpc_type, *nodes)
        @nodes = nodes.dup
        case @mpc_type = mpc_type.upcase
        when "LINEAR","QUADRATIC","BILINEAR","C BIQUAD",
             "P LINEAR", "T LINEAR",
             "P BILINEAR", "T BILINEAR"
          @independent_nodes = [nodes.shift]
          @dependent_nodes = nodes
        when  "BEAM","ELBOW", "LINK", "PIN", "TIE"
          @dependent_nodes = [nodes.shift]
          @independent_nodes = [nodes.shift]
        when "REVOLUTE", "SLIDER", "UNIVERSAL","V LOCAL"
          @dependent_nodes = [nodes.shift]
          @independent_nodes = nodes
        when "CYCLSYM"
          @independent_nodes = [nodes.shift]
          @dependent_nodes = [nodes.shift]
          @ref_nodes = nodes
        when "SS LINEAR", "SS BILINEAR","SSF BILINEAR"
          @independent_nodes = [nodes.shift]
          @dependent_nodes = nodes
        end
        @@all[@type] ||= []
        @@all[@type] <<  self
        @@all[:all] ||= []
        @@all[:all] << self
      end
      attr_reader :independent_nodes, :dependent_nodes, :mpc_type
      alias :deps :dependent_nodes
      alias :inds :independent_nodes
      alias :type :mpc_type

      def dependent_node
        raise "dep for #{@dependent_nodes}" unless @dependent_nodes.size == 1
        @dependent_nodes[0]
      end
      def independent_node
        raise "dep for #{@independent_nodes}" unless @independent_nodes.size == 1
        @independent_nodes[0]
      end
      alias :dep :dependent_node
      alias :ind :independent_node

      def self.independent_nodes(dep_nid = nil)
        if dep_nid
          @@all.values.flatten.select{|m| m.deps.include?(dep_nid.to_s)}.map{|m| m.inds}.flatten.sort.uniq
        else
          @@all.values.flatten.map{|m| m.ind}.flatten.sort.uniq
        end
      end
      def self.dependent_nodes(ind_nid = nil)
        if ind_nid
          @@all.values.flatten.select{|m| m.inds.include?(ind_nid.to_s)}.map{|m| m.deps}.flatten.sort.uniq
        else
          @@all.values.flatten.map{|m| m.deps}.flatten.sort.uniq
        end
      end
      def self.inds(nid = nil)
        self.independent_nodes(nid)
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
      @ind = "3"
      @dep = "6"
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
    def test_inds
      assert_equal([@ind], @mpc.inds)
    end
    def test_dep
      assert_equal(@dep, @mpc.dep)
    end
    def test_deps
      assert_equal([@dep], @mpc.deps)
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
      assert_equal(["2"], Abaqus::MPC[0].deps)
      assert_equal(["3"], Abaqus::MPC[1].deps)
      assert_equal(["4"], Abaqus::MPC[2].deps)
    end
    def test_dep
      assert_equal("2", Abaqus::MPC[0].dep)
      assert_equal("3", Abaqus::MPC[1].dep)
      assert_equal("4", Abaqus::MPC[2].dep)
    end
    def test_independent
      assert_equal("1", Abaqus::MPC[0].ind)
      assert_equal("1", Abaqus::MPC[1].ind)
      assert_equal("6", Abaqus::MPC[2].ind)
    end
    def test_independents
      assert_equal(["1"], Abaqus::MPC[0].inds)
      assert_equal(["1"], Abaqus::MPC[1].inds)
      assert_equal(["6"], Abaqus::MPC[2].inds)
    end
    def test_size
      assert_equal(3, Abaqus::MPC.size)
    end
    def test_type
      assert_equal("BEAM", Abaqus::MPC[0].type)
      assert_equal("LINK", Abaqus::MPC[1].type)
      assert_equal("BEAM", Abaqus::MPC[2].type)
    end
    def test_deps
      assert_equal(["2","3","4"], Abaqus::MPC.deps)
    end
    def test_dependent_nodes
      assert_equal(%w(2 3 4), Abaqus::MPC.dependent_nodes)
    end
    def test_deps_with_arg
      assert_equal(%w(2 3), Abaqus::MPC.deps(1))
    end
    def test_inds
      assert_equal(%w(1 6), Abaqus::MPC.inds)
    end
    def test_independent_nodes
      assert_equal(%w(1 6), Abaqus::MPC.independent_nodes)
    end
    def test_independent_nodes_with_arg
      assert_equal(["1"], Abaqus::MPC.independent_nodes(2))
    end
  end
end

