
unless defined?(ABAQUS_NODE)
  ABAQUS_NODE = true

  require 'abaqus/nset'
  require 'abaqus/inp'

  module Abaqus
    class Node
      extend Inp
      attr :i
      attr :x
      attr :y
      attr :z
      @@all = {}
      @@maxid = 0
      UpperLimitID = 9999999
      def Node.[](i)
        raise RangeError,"Node Id 0 is not allowed" if i == 0
        raise RangeError,"Negative Node ID is not allowed" if i < 0
        raise RangeError,"Given ID of #{i} exceeds limit value of #{UpperLimitID}." if i > UpperLimitID
        @@all[i]
      end
      def Node.add(x,y,z=0.0)
        Node.new(nextid,x,y,z)
      end
      def Node.nextid
        @@maxid + 1
      end
      def Node.size
        @@all.size
      end
      #Maximum ID number
      def Node.maxid
        if size == 0
          nil
        else
          size - 1
        end
      end
      def initialize(i,x,y,z=0.0)
        if i > UpperLimitID
          raise RangeError,"given id (#{i}) exeeds upper limit (#{UpperLimitID})"
        end
        if i < 1
          raise RangeError,"given id must be greater than zero"
        end
        @i = i
        @x = x
        @y = y
        @z = z
        @@all[i] = self
        @@maxid = i if @@maxid < i
      end
      def Node.clear
        @@all.clear
        Nset.clear
        @@maxid = 0
      end
      def Node.parse(line,body)
        keyword, options = parse_command(line)
        unless keyword == "*NODE"
          raise ArgumentError, "Node.parse can treat *node keyword only."
        end
        ns = nil
        name = options["NSET"]
        if name
          ns = Nset[name] || Nset.new(name)
        else
          ns = []
        end

        line = parse_data(body) do |str|
          i,x,y,z = * str.split(/,/)
          y ||= 0.0
          z ||= 0.0
          Node.new(i.to_i,x.to_f,y.to_f,z.to_f)
          ns << i.to_i if ns
        end
        return line, ns.to_a
      end
    end
    def to_s
      s = "#{@i},  #{@x},  #{@y}"
      s += ",  #{@z}" unless @z != 0.0
      return s
    end
    def inspect
      "#<Abaqus::Node[#{@i}]:#{@x},#{@y},#{@z}>"
    end
  end

end

if $0 == __FILE__
  require 'test/unit'
  require 'flexmock/test_unit'
  class TestNode < Test::Unit::TestCase
    def setup
    end
    def teardown
      Abaqus::Node.clear
    end
    def test_none
      assert_equal(0, Abaqus::Node.size)
    end
    def test_first_next_id_should_be_one
      assert_equal(1, Abaqus::Node.nextid)
    end
    def test_next_id_must_be_inremented_of_max_id
      i = rand(30000)
      Abaqus::Node.new(i,0.0,0.0,0.0)
      assert_equal(i+1,Abaqus::Node.nextid)
    end
    def test_Node0_must_raise_out_of_range_error
      assert_raise(RangeError){
        Abaqus::Node[0]
      }
    end
    def test_Node_new_must_returns_instance_of_Node
      n = Abaqus::Node.new(1,0.0,0.0,0.0)
      assert_instance_of(Abaqus::Node,n)
    end
    def test_id_should_be_same_as_given_for_new
      i = rand(300)
      n = Abaqus::Node.new(i,0.0,0.0,0.0)
      assert_equal(i,n.i)
    end
    def test_x_of_instance_must_be_same_as_given_x_for_new
      x = 398.0*rand()
      n = Abaqus::Node.new(2,x,0.0,0.0)
      assert_in_delta(x, n.x, x*0.00001)
    end
    def test_raise_range_error_for_negative_id
      assert_raise(RangeError){
        Abaqus::Node[-3]
      }
    end
    def test_raise_range_error_for_over_upper_limit_of_id
      # Abaqus allows upto 9999999 as node id
      assert_raise(RangeError){
        Abaqus::Node[Abaqus::Node::UpperLimitID + 1]
      }
    end
    def test_raise_range_error_for_creating_with_node_id_over_upper_limit
      assert_raise(RangeError){
        Abaqus::Node.new(Abaqus::Node::UpperLimitID + 1, 0.0,0.0,0.0)
      }
    end
    def test_return_nil_for_not_existed_id
      assert_nil(Abaqus::Node[1])
    end
    def test_raise_range_error_if_negative_id_was_given
      assert_raise(RangeError){
        Abaqus::Node.new(-1,0.0,0.0,0.0)
      }
    end
    def test_y_must_be_same_as_third_argument_of_new
      y = rand()*89783
      n = Abaqus::Node.new(1,0.0,y,0.0)
      assert_in_delta(y,n.y,y*0.000001)
    end
    def test_z_must_be_zero_if_fourth_argument_was_omitted
      n = Abaqus::Node.new(1,0.0,0.0)
      assert_equal(0.0, n.z)
    end
    def test_z_must_be_same_as_fourth_argument_of_new
      z = rand()*6372
      n = Abaqus::Node.new(1,0.0,0.0,z)
      assert_in_delta(z, n.z, z*0.000001)
    end
  end

  class TestNodeCreationWithIntervalNodeID < Test::Unit::TestCase
    def setup
      @n1 = Abaqus::Node.new(1, 0.1, 0.0, 0.0)
      @n2 = Abaqus::Node.new(10, 1.0, 0.0, 0.0)
    end
    def teardown
      Abaqus::Node.clear
    end
    def test_n1
      assert_equal(1, @n1.i)
    end
    def test_n2
      assert_equal(10, @n2.i)
    end
    def test_size
      assert_equal(2, Abaqus::Node.size)
    end
    def test_nextid
      assert_equal(11, Abaqus::Node.nextid)
    end
    def test_added_id_should_be_12
      n = Abaqus::Node.add(2.0,4.0,7.0)
      assert_equal(11, n.i)
    end
  end
  class TestNodeParse < Test::Unit::TestCase
    def setup
      @body = flexmock("mIO")
      @body.should_receive(:each).and_raise(NameError)
    end
    def teardown
      Abaqus::Node.clear
    end
    def test_parse_returns_next_command_and_node_ids
      @body.should_receive(:gets).twice.and_return("1, 0.0, 0.0, 0.0",nil)
      res = Abaqus::Node.parse("*NODE",@body)
      assert_instance_of(Array, res)
    end
    def test_parse_returns_nil_at_end_of_file
      @body.should_receive(:gets).times(3).and_return("1, 0.0, 0.0, 0.0",
                                                      "2, 0.0, 0.0, 0,0",
                                                      nil)
      res, ids = Abaqus::Node.parse("*node",@body)
      assert_nil(res)
    end
    def test_parse_should_return_created_id_list_as_second_retval
      @body.should_receive(:gets).times(4).and_return("1, 0.0, 0.0",
                                                      "3, 1.0, 0.0",
                                                      "5, 0.0, 1.0",
                                                      nil)
      ans = [1,3,5]
      res, ids = Abaqus::Node.parse("*node", @body)
      assert_equal(ans,ids.sort)
    end


  end

end

