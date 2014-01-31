
unless defined?(ABAQUS_LOAD_RB)
  ABAQUS_LOAD_RB = true

  require "abaqus/inp"

  module Abaqus
    class Load
      extend Inp
      def initialize(nid)
        @nid = nid
        @vals = {}
        @@all[nid] = self
      end
      private_class_method :new
      def self.[](nid)
        @@all[nid] ||= new(nid)
      end
      attr_reader :nid
      def self.clear
        @@all.clear
      end
      def self.size
        @@all.size
      end
      def add(dof, value)
        @vals[dof.to_i] ||= 0.0
        @vals[dof.to_i] += value.to_f
      end
      def [](dof)
        @vals[dof]
      end
      def dofs
        @vals.keys
      end
      def each
        @vals.each do |content|
          yield content
        end
      end
      def self.parse(head,body)
        key, opts = parse_command(head)
        res = parse_data(body){|arg|
          n, d, v = arg.split(/,/).map{|x| x.strip}
          if sets = parent.class.parent.nsets[n]
            sets.each do |nid|
              self[nid].add d, v
            end
          else
            self[n].add d, v
          end
        }
        res
      end
    end
    class DLoad
      extend Inp
      def initialize(eid, type, *values)
        @eid = eid
        @type = type
        @values = values
      end
      attr_reader :eid, :type, :value

      def self.[](eid)
        @@all[eid]
      end
      def self.clear
        @@all.clear
      end

      def self.parse(head,body)
        key, opts = parse_command(head)
        res = parse_data(body){|arg|
          e, t, *vals = arg.split(/,/).map{|x| x.strip}
          case t
          when /^(TRVEC\d?|TRSHR\d?|EDLD\d?|TRVEC)(NU)?/
            # Add special treatment if it required.
          end
          step = parent
          model = step.class.parent
          set = model.elsets[e]
          unless set.nil?
            set.each do |eid|
              self.new(eid, t, *vals)
            end
          else
            self.new(e, t, *vals)
          end
        }
        res
      end
    end
  end

end


if $0 == __FILE__
  require 'test/unit'
  require 'flexmock/test_unit'

  class TestCLoadSolo < Test::Unit::TestCase
    def teardown
      Abaqus::Load.clear
    end
    def test_new_single
      assert_raise(NoMethodError){ Abaqus::Load.new(4)}
      assert Abaqus::Load[3]
    end
    def test_new_args
      assert_raise(NoMethodError){ Abaqus::Load.new }
      assert_raise(NoMethodError){ Abaqus::Load.new(1,2) }
    end
    def test_create_with_same_id
      nid = 66
      load1 = Abaqus::Load[nid]
      load2 = Abaqus::Load[nid]
      assert load1
      assert_equal load1, load2
      assert_equal 1, Abaqus::Load.size
    end
    def test_add
      nid = 4
      dof = 2
      val = 3.0
      cload = Abaqus::Load[nid]
      assert_equal [], cload.dofs
      cload.add(dof, val)
      assert_equal [dof], cload.dofs
      assert_in_delta val, cload[dof], 0.01
    end
    def test_multi_dof
      nid = 4
      dof1 = 3
      val1 = 3.0
      dof2 = 1
      val2 = 9.8
      Abaqus::Load[nid].add dof1, val1
      Abaqus::Load[nid].add dof2, val2
      assert_equal [dof1, dof2].sort, Abaqus::Load[nid].dofs.sort
    end
    def test_parse
      m = flexmock("Test")
      head = "*CLOAD"
      dummy = "*DUMMY\n"
      nid = 4
      dof = 2
      val = "3.4"
      val2= "6.9"
      m.should_receive(:gets).and_return(
        "*HEADING\n",
        "*STEP\n",
        "*CLOAD\n",
        "#{nid}, #{dof}, #{val}\n",
        "#{nid+1}, #{dof+1}, #{val2}\n",
        "*END STEP\n",
        nil
      )
      model =  Abaqus.parse(m)
      assert step = model.steps.first
      assert loads = step.loads
      p1 = loads[nid]
      p2 = loads[nid+1]
      assert p1, "p1"
      assert p2, "p2"
      assert_equal [dof], p1.dofs
      assert_equal [dof+1], p2.dofs
    end
  end
  class TestDLoad < Test::Unit::TestCase
    def teardown
      Abaqus::DLoad.clear
    end
    def test_new_pressure
      eid = 7
      type = "P"
      values = [0.0, 1.0, 0.0]

      dl = Abaqus::DLoad.new(eid, type, *values)
      assert_equal dl, Abaqus::DLoad[0]
    end
  end
end
