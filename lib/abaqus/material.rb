

dir = File::dirname(__FILE__)
require dir + "/inp"
module Abaqus
  class Material
    @@all = {}
    extend Inp
    SubKeywords=%w(*ELASTIC *PLASTIC *DENSITY)
    SubKeywords << "*NO COMPRESSION" << "*NO TENSION" <<
    "*FAIL STRAIN" << "*FAIL STRESS" <<
    "*POROUS ELASTIC" << "*HYPOELASTIC" <<
    "*HYPERELASTIC" << "*HYPERFOAM" <<
    "*ANISOTROPIC HYPERELASTIC" <<
    "*VISCOELASTIC" << "*MULLINS EFECT" <<
    "*HYSTERESIS" << "*LOW DENSITY FOAM" <<
    "*POTENTIAL" << "*CYCLIC HARDENING" <<
    "*RATE DEPENDENT" << "*CREEP" << "*CREEP STRAIN RATE CONTROL" <<
    "*SWELLING" << "*RATIOS" << "*ANNEAL TEMPERATURE" <<
    "*SHEAR FAILURE" << "*TENSILE FAILURE" << "*DAMAGE INITIATION" <<
    "*DAMAGE EVOLUTION" << "*VOID NUCLEATION" <<
    "*CAST IRON COMPRESSION HARDENING" <<
    "*CASt IRON PLASTICITY" << "*CAST IRON TENSION HARDENING" <<
    "*VISCOUS" << "*ORNL" << "*DEFORMATION PLASTICITY" <<
    "*DRUCKER PRAGER" << "*DRUCKER PRAGER HARDENING" <<
    "*CAP PLASTICITY" << "*CAP HARDENING" << "*CAP CREEP" <<
    "*MOHR COULOMB" << "*MOHR COULOMB HARDENING" <<
    "*CLAY PLASTICITY" << "*CLAY HARDENING" <<
    "*CRUSHABLE FOAM" << "*CRUSHABLE FOAM HARDENING" <<
    "*FABRIC" << "*UNIAXIAL" <<
    "*LOADING DATA" << "*UNLOADING DATA" << "*EXPANSION" <<
    "*JOINTED MATERIAL" << "*CONCRETE" << "*SHEAR RETENSION" <<
    "*FAILURE RATIOS" << "*BRITTLE CRACKING" << "*BRITTLE FAILURE" <<
    "*BRITTLE SHEAR" << "*CONCRETE DAMAGED PLASTICITY" <<
    "*CONCRETE TENSION STIFFENING" << "*CONCRETE COMPRESSION HARDENING" <<
    "*CONCrETE TENSION DAMAGE" << "*CONCRETE COMPRESSION DAMAGE"<<
    "*DAMPING" << "*MODAL DAMPING"
    # need more keywords. check abaqus manual

    def self.parse(head, body)
      key, opts = parse_command(head)
      unless key == "*MATERIAL"
        raise ArgumentError, "Material.parse needs *MATERIAL keywords, but #{key} was given."
      end
      name = opts["NAME"]
      contents = []
      while res = parse_data(body){|line| contents << line}
        key, ops = parse_command(res)
        if SubKeywords.include?(key)
          contents << res
        else
          break
        end
      end
      mat = self.new(name,contents)
      return res, mat
    end
    def initialize(name, cont=nil)
      @contents = cont
      @name = name
      @@all[name] = self
    end
    attr :name
  end
end

if $0 == __FILE__
  require 'test/unit'
  require 'flexmock/test_unit'
  class TestMaterial < Test::Unit::TestCase
    def setup
      @name = "testmat"
    end
    def teardown
    end
    def test_new_with_name
      mat = Abaqus::Material.new(@name)
      assert_equal(@name, mat.name)
    end
  end
  class TestMaterial_Parse < Test::Unit::TestCase
    def setup
      @body = flexmock
      @young = 2e5
      @poison = 0.3
      @name = "TMAT"
      @head = "*MATERIAL, NAME=#{@name}"
      str = <<-NNN
*elastic
#{@young}, #{@poison}
*plastic, hardening=kinematic
0.0, 230.
0.15, 400.
      NNN
      @body.should_receive(:gets).and_return(str.to_s)
    end
    def teardown
    end
    def test_parse_material_name
      line, mat = Abaqus::Material.parse(@head,@body)
      assert_equal(@name, mat.name)
    end
  end
end
