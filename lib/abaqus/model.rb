pos = 'abaqus'

require pos + '/upcasehash'

unless defined?(ABAQUS_MODEL_RB)
  ABAQUS_MODEL_RB = true

  module Abaqus

    module MPC_Access
      def independent_nodes
        self.values.map{|x| x.ind}.sort.uniq
      end
      def dependent_nodes(nid = nil)
        if nid
          self.keys.select{|x| @@all[x].ind == nid}.sort
        else
          self.keys.sort
        end
      end
      def inds
        self.independent_nodes
      end
      def deps(nid = nil)
        self.dependent_nodes(nid)
      end
    end

    class ElementHash < UpcaseHash
      def initialize(parent, instances)
        @parent = parent
        @instances = instances
      end
      def [](key)
        res = super
        unless res
          name, eid = key.upcase.split(/\./)
          if eid
            inst = @instances[name]
            if inst
              res = inst.element(eid.to_i)
            end
          end
        end
        res
      end
    end

    class NodeHash < UpcaseHash
      def initialize(parent, instances)
        @parent = parent
        @instances = instances
      end
      attr :parent
      attr :instances
      def [](key)
        num = key.to_i
        nd = nil
        name = nil
        nid = nil
        if num > 0 then
          nd = super(num)
        else
          name, nid = key.upcase.split(/\./)
          if nid
            inst = @instances[name]
            unless inst.nil?
              nd = inst.node(nid.to_i)
              if nd.nil? then 
                open("dump.txt","wb") do |out|
                  out.puts "Node #{key} does not exist."
                  out.puts "num=#{num}\n nid=#{nid}\n name=#{name}"
                  out.puts inst.inspect
                end
                raise "node #{nid} does not found in #{name}. see dump.txt for details."
              end
            else
              open("dump.txt","wb") do |out|
                  out.puts "Node #{key} does not exist."
                  out.puts "num=#{num}\n nid=#{nid}\n name=#{name}"
                  out.puts @instances.object_id
                  out.puts @instances.keys
                  out.puts @parent.name
                  out.puts @parent.instances.object_id
              end
              raise "instance #{name} is not found in the model. see dump.txt for details."
            end
          else
            raise "nid is not true (#{nid.inspect})."
          end
        end
        raise "Node #{key} does not exist.(num=#{num}, nid=#{nid}, name=#{name})" unless nd
        nd
      end
    end

    ########################################################################
    class Model
      @@all = UpcaseHash.new

      def self.[](name)
        @@all[name] || Model.new(name)
      end

      def initialize(name)
        raise "model '#{name}' is already exist. Use Model.[] instead of Model.new." if @@all.member?(name)
        upcase_hash = UpcaseHash.new

        @instances = upcase_hash.clone
        @elements = ElementHash.new(self, @instances)
        @nodes = NodeHash.new(self, @instances)
        @parts = upcase_hash.clone
        @nsets = upcase_hash.clone
        @elsets = upcase_hash.clone
        @bcs = upcase_hash.clone
        @loads = upcase_hash.clone
        @properties = upcase_hash.clone
        @materials = upcase_hash.clone
        @mpcs = {}
        @mpcs.extend MPC_Access
        @name = name
        @steps = []  # step must be array to keep order
      end
      %w(name nodes elements nsets elsets bcs parts instances
       loads steps properties materials mpcs).each do |var|
        attr var # remove @
       end
      @@all[name] = self
    end
    GlobalModel = Model.new("global")

  end

  require pos + '/binder'

  require pos + '/node'
  require pos + '/nset'
  require pos + '/element'
  require pos + '/elset'
  require pos + '/property'
  require pos + '/part'
  require pos + '/instance'
  require pos + '/bc'
  require pos + '/load'
  require pos + '/step'
  require pos + '/material'
  require pos + '/mpc'

  module Abaqus
    class Model
      BindTargets = [Node, Element, Nset, Elset, Part, Instance,
        Bc, Load, Step, Property, Material,MPC]
      BindTargets.each do |target|
        Binder.inject_bind_methods(target)
      end
      def with_bind
        bind_all
        yield
        release_all
      end
      def bind_all
        BindTargets.each do |klass|
          klass.bind(self)
        end
      end
      def release_all
        BindTargets.each do |klass|
          klass.release
        end
      end
      # set property reference into elements
      def expand_properties
        @properties.each do |key,value|
          value.expand_to_element self
        end
      end
    end
    GlobalModel.bind_all
  end

end

if $0 == __FILE__
  require 'test/unit'
  require 'flexmock'

  class TestModel < Test::Unit::TestCase
    def setup
      @name = "TestModel"
      @m = Abaqus::Model.new(@name)
    end
    def test_nodes
      assert_not_nil(@m.nodes)
    end
    def test_nsets
      assert_not_nil(@m.nsets)
    end
    def test_elements
      assert_not_nil(@m.elements)
    end
    def test_elsets
      assert_not_nil(@m.elsets)
    end
    def test_bcs
      assert_not_nil(@m.bcs)
    end
    def test_loads
      assert_not_nil(@m.loads)
    end
    def test_steps
      assert_not_nil(@m.steps)
    end
    def test_props
      assert_not_nil(@m.properties)
    end
    def test_mpc
      assert_not_nil(@m.mpcs)
    end
    def test_nodes_add
      @m.nodes[0] =  99
      assert_equal(99, @m.nodes[0])
    end
    def test_name
      assert_equal(@name, @m.name)
    end
    def test_materials
      assert_not_nil(@m.materials)
    end
    def test_mpc_dependent_nodes
      assert_nothing_raised do
        assert_instance_of(Array, @m.mpcs.dependent_nodes)
      end
    end
    def test_mpc_independent_nodes
      assert_nothing_raised do
        assert_instance_of(Array, @m.mpcs.independent_nodes)
      end
    end
  end
end

