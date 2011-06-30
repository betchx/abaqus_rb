dir = File::dirname(__FILE__)
require dir+'/abaqus/model'
require dir+'/abaqus/node'
require dir+'/abaqus/element'
require dir+'/abaqus/mpc'

module Abaqus
  KnownKeywords = {
    "*NODE"     => Node,
    "*ELEMENT"  => Element,
    "*NSET"     => Nset,
    "*ELSET"    => Elset,
    "*BOUNDARY" => Bc,
    "*MATERIAL" => Material,
    "*STEP"     => Step,
    "*MPC"      => MPC,
  }
  Property_Keywords = [
    "*SHELL SECTION" ,
    "*BEAM SECTION" ,
    "*SOLID SECTION" ,
    "*BEAM GENERAL SECTION",
    "*SPRING",
    #"",
  ]
  Property_Keywords.each do |key|
    KnownKeywords[key] = Property
  end

  class SkipParser
    def self.parse(line, body)
      line = body.gets
      return nil if line.nil?
      return Inp.parse_data(body) {}
    end
  end
  module_function
  def parse(f,name)
    model = Model.new(name)
    model.with_bind do
      line = f.gets
      line = f.gets while line[0,2] == "**"
      keywords, opts = Inp.parse_command(line)
      raise "first keyword must be *heading" unless keyword = "*HEADING"
      line = Inp.parse_data(f) {} # skip
      while line
        keyword, ops = Inp.parse_command(line)
        klass = KnownKeywords[keyword] || SkipParser
        line, args = klass.parse(line, f)
      end
    end
    return model
  end
end


if $0 == __FILE__
  require 'test/unit'
  require 'flexmock/test_unit'
  class TestAbaqusParseSmall<Test::Unit::TestCase
    def setup
      str = <<-KKK
*heading
this is comment.
multi line comment is allowed
*node
 1, 0, 0, 0
 2, 1, 0, 0
 3, 0, 1, 0
 4, 1, 1, 0
11, 0, 0, 1.0
12, 1, 0, 1.0
13, 0, 1, 1.0
14, 1, 1, 1.0
*step
*static
0.1, 1.0
*cload
top, 2, -0.1
*EL FILE, freq=0
*NODE FILE, freq=1
U
*NODE FILE, NSET=FIX, freq=1
RF
*end step
      KKK
      arr = str.to_a
      arr << nil
      mock = flexmock("Short")
      mock.should_receive(:gets).with_no_args.times(arr.size).and_return(*arr)
      @model = Abaqus::parse(mock,"short")
    end
    def test_model
      assert_instance_of(Abaqus::Model, @model)
    end
  end
  class TestAbaqusParseOK  < Test::Unit::TestCase
    def setup
      ok_str = <<-NNN
*heading
this is comment.
multi line comment is allowed
*node
 1, 0, 0, 0
 2, 1, 0, 0
 3, 0, 1, 0
 4, 1, 1, 0
11, 0, 0, 1.0
12, 1, 0, 1.0
13, 0, 1, 1.0
14, 1, 1, 1.0
*element, type=s4,elset=xy
1, 1, 2, 4, 3
2, 11, 12, 14, 13
*element, type=s4, elset=xz
11, 1, 2, 12, 11
12, 3, 4, 14, 13
*element, type=s4, elset=yz
21, 1, 11, 13, 3
22, 2, 12, 14, 4
*nset, nset=fix
1
*nset, nset=top, generate
3,4
13,14,1
*boundary
fix, 1, 6, 0
*shell section, elset=xy, material=steel
0.1
*shell section, elset=xz, material=steel
0.15
*shell section, elset=yz, material=steel
0.15
*material, name=steel
*elastic
2e5, 0.3
*plastic, hardening=kinematic
0.0, 245.0
0.15, 400
*mpc
BEAM, 1, 22
*step
*static
0.1, 1.0
*cload
top, 2, -0.1
*EL FILE, freq=0
*NODE FILE, freq=1
U
*NODE FILE, NSET=FIX, freq=1
RF
*end step
      NNN
      mock = flexmock("test.inp")
      a = ok_str.to_a
      a << nil
      mock.should_receive(:gets).times(a.size).and_return(*a)
      @model = Abaqus::parse(mock,"OK test")
    end

    def test_element_size
      assert_equal(6, @model.elements.size)
    end
    def test_no_change_of_global_element
      assert_equal(0, Abaqus::Element.size)
    end
    def test_node_size
      assert_equal(8, @model.nodes.size)
    end
    def test_no_change_of_global_node
      assert_equal(0, Abaqus::Node.size)
    end
    def test_nset_size
      assert_equal(2, @model.nsets.size)
    end
    def test_no_change_of_global_nset
      assert_equal(0, Abaqus::Nset.size)
    end
    def test_elset_size
      assert_equal(3, @model.elsets.size)
    end
    def test_no_change_of_global_elset
      assert_equal(0, Abaqus::Elset.size)
    end
    def test_elset_xy
      assert_not_nil(@model.elsets["XY"])
      assert_equal(2, @model.elsets["XY"].size)
    end
    def test_step_size
      assert_equal(1, @model.steps.size)
    end
    def test_materials_size
      assert_equal(1, @model.materials.size)
    end
    def test_material_steel
      assert_not_nil(@model.materials["STEEL"])
    end
    def test_pops_size
      assert_equal(3, @model.properties.size)
    end
    def test_bcs_exist
      assert( ! @model.bcs.empty? )
    end
    def test_properties_by_name
      assert_in_delta(0.1, @model.properties["XY"][0][0].to_f, 0.001)
    end
    def test_material_of_property
      assert_equal("STEEL", @model.properties["XY"].material)
    end
    def test_mpc_size
      assert_equal(1, @model.mpcs.size)
    end

  end
end
