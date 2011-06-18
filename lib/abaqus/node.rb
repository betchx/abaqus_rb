

module Abaqus
  class Node
    attr :i
    attr :x
    attr :y
    attr :z
    @@all = []
    UpperLimitID = 9999999
    def Node.[](i)
      raise RangeError,"Node Id 0 is not allowed" if i == 0
      raise RangeError,"Negative Node ID is not allowed" if i < 0
      raise RangeError,"Given ID of #{i} exceeds limit value of #{UpperLimitID}." if i > UpperLimitID
      @@all[i]
    end
    def Node.add(x,y,z=0.0)
      Node.new(@all.size,x,y,z)
    end
    def Node.nextid
      @@all.size
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
    end
    def Node.clear
      @@all.clear
    end
    def Node.parse(line,io)
      # no need to parse first line
      line = io.gets
      until line.nil? || line =~ /^\*[^*]/
        i,x,y,z = * line.strip.split(/,/)
        y ||= 0.0
        z ||= 0.0
        Node.new(i.to_i,x.to_f,y.to_f,z.to_f)
      end
      line
    end
  end
  def to_s
    s = "#{@i},  #{@x},  #{@y}"
    s += ",  #{@z}" unless @z != 0.0
    return s
  end
end

if $0 == __FILE__
  require 'test/unit'
  class TestNode < Test::Unit::TestCase
    def setup
    end
    def teardown
      Abaqus::Node.clear
    end
    def test_none
      assert_equal(0, Abaqus::Node.size)
    end
    def test_first_next_id_is_zero
      assert_equal(0, Abaqus::Node.nextid)
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
end

