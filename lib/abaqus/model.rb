

module Abaqus
  class Model
    def initialize(name)
      @name = name
      @elements = {}
      @nodes = {}
      @nsets = {}
      @elsets = {}
      @bcs = {}
      @loads = {}
      @steps = []  # step must be array to keep order
      @properties = {}
      @materials = {}
    end
    %w(name nodes elements nsets elsets bcs
       loads steps properties materials).each do |var|
      attr var # remove @
    end
  end
  GlobalModel = Model.new("global")
end

pos = File::dirname(__FILE__)

require pos + '/node'
require pos + '/nset'
require pos + '/element'
require pos + '/elset'
require pos + '/property'
require pos + '/bc'
require pos + '/load'
require pos + '/step'
require pos + '/material'
require pos + '/binder'

module Abaqus
  class Model
    BindTargets = [Node, Element, Nset, Elset,
      Bc, Load, Step, Property, Material]
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
  end
  GlobalModel.bind_all
end


if $0 == __FILE__
  require 'test/unit'
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
  end
end

