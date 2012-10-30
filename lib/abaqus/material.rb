
unless defined?(ABAQUS_MATERIAL_RB)
  ABAQUS_MATERIAL_RB = true

require "abaqus/inp"
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
        break unless  SubKeywords.include?(key)
        contents << res
      end
      mat = self.new(name,contents)
      return res, mat
    end

    def initialize(name, cont=nil)
      @contents = cont
      @name = name
      @@all[name] = self
      parse_contents
    end
    attr_reader :name, :elastic_modulus, :poison_rate, :density

    # Parse Material definition
    def parse_contents
      if @contents
        a = @contents.dup
        def a.gets
          self.shift
        end
        while res = Inp.parse_data(a)
          key, ops = Inp.parse_command(res)
          case key
          when "*ELASTIC"
            @elastic_modulus, @poison_rate = a.gets.split(/,/)[0..1].map{|x| x.to_f}
          when "*DENSITY"
            @density = a.gets.split(/,/).shift.to_f
          end
        end
      end
    end
  end
end

end  #unless defined?

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
      @dens = 7.6
      str = <<-NNN
*elastic
#{@young}, #{@poison}
*plastic, hardening=kinematic
0.0, 230.
0.15, 400.
*density
#{@dens}
*STEP
      NNN
      @body.should_receive(:gets).and_return(*str.to_a)
    end
    def teardown
    end
    def test_parse_material_name
      line, mat = Abaqus::Material.parse(@head,@body)
      assert_equal(@name, mat.name)
    end
    def test_elastic_modulus
      line, mat = Abaqus::Material.parse(@head,@body)
      assert_in_delta(@young, mat.elastic_modulus,0.1)
    end
    def test_poison_rate
      line, mat = Abaqus::Material.parse(@head,@body)
      assert_in_delta(@poison, mat.poison_rate, 0.001)
    end
    def test_density
      line, mat = Abaqus::Material.parse(@head,@body)
      assert_in_delta(@dens, mat.density, 0.001)
    end
  end
end
