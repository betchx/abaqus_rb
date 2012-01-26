

unless defined?(Abaqus::Element::S3)

require 'abaqus/element_base'

module Abaqus
  class Element
    class S3 < Element
      def initialize(i,n1,n2,n3)
        @nodes = [n1,n2,n3]
        @i = i
        assign
      end
      attr_reader :i
      def [](n)
        if n < 3 && n > -4
          @nodes[n]
        else
          raise ArgumentError,"index must be between 0 and 2"
        end
      end
      def assign
        super(@i,self)
      end
      private :assign

      def type
        "S3"
      end
      def nodes
        @nodes
      end
      def self.parse_line(line)
        i,n1,n2,n3, n5 = * line.split(/,/)
        if n5
          raise RuntimeError, "Too many nodes are given"
        end
        unless n3
          raise RuntimeError, "Given nodes are not enough"
        end
        return i,n1,n2,n3
      end
      def self.parse(line,io)
        self.new(*parse_line(line).map{|x| x.to_i})
      end
      #Element.register("S3",self)
      #Element.regist_as_basic_element(/^S3/,self)
      Element::BasicElementMap << [/^S3/,self]
    end
  end
end

end



if $0 == __FILE__
unless defined?(Abaqus::Node)
  require pos+"/node"
end
unless defined?(Abaqus::Model)
  require pos+"/model"
end
  require 'test/unit'
  require 'flexmock/test_unit'
  class TestElementS3 < Test::Unit::TestCase

    def setup
      @nodes = [1,2,3,4,5,6,7,8]
      @nodes.each do |i|
        z = (i-1) / 4
        y = ((i-1) / 2) % 2
        x = (i-1) % 2
        Abaqus::Node.new(i,x,y,z)
      end
    end
    def s3
      @s3id = 1
      Abaqus::Element::S3.new(@s3id,1,2,3)
    end
    def teardown
      Abaqus::Element.clear
    end
    def test_element_new_is_not_allowed
      assert_raise(RuntimeError){
        Abaqus::Element.new
      }
    end
    def test_initially_Element_has_empty_list
      assert_equal(0,Abaqus::Element.size)
    end

    ######S3

    def test_S3_new_keeps_order_of_node
      e = s3

      assert_equal(1,e[0])
      assert_equal(2,e[1])
      assert_equal(3,e[2])
    end
    def test_S3_must_raise_ArgumentError_if_node_id_query_with_over_2
      e = s3
      assert_raise(ArgumentError){
        e[3]
      }
    end
    def test_S3_must_raise_ArgumentError_if_node_id_query_with_less_than_minus_4
      e = s3
      assert_raise(ArgumentError){
        e[-4]
      }
    end
    def test_S3_nid_minus_3_must_return_same_value_of_idx_0
      e = s3
      assert_equal(e[0],e[-3])
    end
    def test_S3_type_must_return_S3
      e = s3
      assert_equal("S3",e.type)
    end
    def test_S3_new_added_to_ElementList
      e = s3
      assert_equal(e, Abaqus::Element[@s3id])
    end

    def test_S3_new_increase_Element_size
      assert_equal(0, Abaqus::Element.size)
      e = s3
      assert_equal(1, Abaqus::Element.size)
    end

    def test_S3_i_must_return_created_id
      e = s3
      assert_equal(@s3id, e.i)
    end

    def test_S3_nodes_method_returns_array_of_nodes_with_its_order
      e = s3
      assert_equal([1,2,3],e.nodes)
    end

    def test_modificaion_of_retval_of_S3_nodes_should_not_affect_original
      e = s3
      a = s3.nodes
      a[0] = 8
      s3.nodes[1] = 9
      assert_not_equal(a[0],e[0])
      assert_not_equal(9, e[1])
      assert_equal(1,e[0])
      assert_equal(2,e[1])
    end
    def test_stored_element_must_be_original_type_S3
      e = s3
      assert_equal(e, Abaqus::Element[@s3id])
    end

    def test_at_first_nextid_should_be_one
      assert_equal(1, Abaqus::Element.nextid)
    end
    def test_creating_first_element_of_eid_1_changes_nextid_to_2
      Abaqus::Element::S3.new(1, 1,2,3)
      assert_equal(2, Abaqus::Element.nextid)
    end
    def test_creation_of_first_element_change_nextid_for_the_elements_id_plus_1
      eid = rand(7438)
      e = Abaqus::Element::S3.new(eid, 1, 2,3)
      assert_equal(eid+1,Abaqus::Element.nextid)
    end

    def test_Element_parse_request_command_is_ELEMENT
      assert_raise(ArgumentError) do
        s = ""
        Abaqus::Element.parse("*elem,",s)
      end
    end
    def test_Element_parse_throw_if_type_parameter_was_not_given
      assert_raise(ArgumentError) do
        s = ""
        Abaqus::Element.parse("*Element",s)
      end
    end
  end
  class TestS3Parse < Test::Unit::TestCase
    def setup
      @cmd = "*Element, type=S3"
      @str1 = <<-NNN
1, 1,2,3
      NNN
      @str2 = <<-KKK
2, 1,2,4
3, 5,6,7
      KKK
      @ids = 0
    end
    def teardown
      Abaqus::Element.clear
    end

    def try_parse(cmd,str)
      body = flexmock("mIO")
      args = str.map
      args << nil
      body.should_receive(:gets).at_most.times(args.size).and_return(*args)
      assert_nothing_raised do
        @res,@ids = Abaqus::Element.parse(cmd,body)
      end
    end
    def test_handle_one_line
      try_parse(@cmd,@str1)
    end
    def test_handle_two_line
      try_parse(@cmd,@str2)
    end

    def test_it_return_list_of_ids_for_one_element
      try_parse(@cmd,@str1)
      assert_equal([1], @ids)
    end
    def test_it_return_list_of_ids_for_two_element
      try_parse(@cmd,@str2)
      assert_equal([2,3],@ids)
    end

    def test_created_element_type_must_be_S4_for_one_elements
      try_parse(@cmd,@str1)
      e = Abaqus::Element[@ids[0]]
      assert_equal("S3",e.type)
    end
    def test_created_element_has_same_element_of_given
      try_parse(@cmd,@str1)
      assert_equal([1,2,3],Abaqus::Element[1].nodes)
    end
    def test_parse_raise_ArgumentError_when_unknown_type_was_given
      assert_raise(NameError){
        Abaqus::Element.parse("*ElemEnt, type=Zero",@str1)
      }
    end
    def test_multiple_definition_of_element_can_be_parsed_correctly
      cmd = "*Element,Elset=A,type=S3"
      second_cmd = "*Element,elset=B,type=S3"
      ans = [
        "1, 1,2,3",
        "2, 5,6,7",
        second_cmd,
        "3, 1,2,5",
        "4, 3,4,7",
        nil
      ]
      body = flexmock("mIO")
      body.should_receive(:gets).at_most.times(ans.size).and_return(*ans)
      res,ids = Abaqus::Element.parse(cmd,body)
      assert_equal([1,2], ids)
      assert_equal(second_cmd,res)
      assert_equal(2, Abaqus::Element.size)
      assert_equal([1,2,3], Abaqus::Element[1].nodes)
      assert_equal("S3", Abaqus::Element[1].type)
      assert_equal([5,6,7], Abaqus::Element[2].nodes)
      assert_equal("S3", Abaqus::Element[2].type)
      res2,ids2 = Abaqus::Element.parse(res,body)
      assert_nil( res2)
      assert_equal([3,4],ids2)
      assert_equal(4, Abaqus::Element.size)
      assert_equal([1,2,3], Abaqus::Element[1].nodes)
      assert_equal("S3", Abaqus::Element[1].type)
      assert_equal([5,6,7], Abaqus::Element[2].nodes)
      assert_equal("S3", Abaqus::Element[2].type)
      assert_equal([1,2,5], Abaqus::Element[3].nodes)
      assert_equal("S3", Abaqus::Element[3].type)
      assert_equal([3,4,7], Abaqus::Element[4].nodes)
      assert_equal("S3", Abaqus::Element[4].type)
    end
    def test_not_sequential_eid_can_be_handed
      cmd = "*Element,Elset=A,type=S3"
      ans = [
        "2, 5,6,7",
        "1, 1,2,3",
        "4, 3,4,7",
        "3, 1,2,5",
        nil
      ]
      body = flexmock("mIO")
      body.should_receive(:gets).at_most.times(ans.size).and_return(*ans)
      res,ids = Abaqus::Element.parse(cmd,body)
      assert_nil(res)
      assert_equal([2,1,3,4].sort, ids.sort)
      assert_equal(4, Abaqus::Element.size)
    end
  end
  class TestElementS3ParseForNonSequencialEID < Test::Unit::TestCase
    def setup
      cmd = "*ELEment, type=S3, elset=A"
      body = flexmock("mIO")
      body.should_receive(:gets).times(5).and_return(
         "  1, 1, 2, 4\n",
          " 11, 5, 6, 8\n",
          "101, 1, 2, 6\n",
          "102, 3, 4, 8\n",
          nil
      )
      $res,$ids = Abaqus::Element.parse(cmd, body)
    end
    def test_nil_was_returned
      assert_nil($res)
    end
    def test_eids
      assert_equal([1,11,101,102], $ids.sort)
    end
    def test_size
      assert_equal(4, Abaqus::Element.size)
    end
    def test_nextid
      assert_equal(103, Abaqus::Element.nextid)
    end
  end
  class TestElsetS3 < Test::Unit::TestCase
    def setup
      @elset_name = "TestElements"
      @cmd = "*element, type=S3, elset=#{@elset_name}"
      @str1 = <<-NNN
1, 1,2,4
      NNN
      @str2 = <<-KKK
2, 1,2,4
3, 5,6,8
      KKK
      @ids = 0
    end
    def teardown
      Abaqus::Element.clear
    end
    def try_parse(cmd,io)
      body = flexmock("mIO")
      strings = io.map{|x| x.to_s}
      strings << nil
      body.should_receive(:gets).at_most.times(strings.size).and_return(*strings)
      assert_nothing_raised{
        @res,@ids = Abaqus::Element.parse(cmd,body)
      }
    end
    def test_can_parse_if_elset_option_was_given
      try_parse(@cmd,@str1)
    end
    def test_elset_was_created_after_parse_with_elset_option
      try_parse(@cmd,@str1)
      assert(Abaqus::Elset[@elset_name])
    end
    def test_elset_must_contain_created_element_id_by_parse
      try_parse(@cmd,@str1)
      assert_equal([1], Abaqus::Elset[@elset_name])
    end
  end
  class TestBindS3 < Test::Unit::TestCase
    def setup
      @name = "BindTestModel"
      @m = Abaqus::Model.new(@name)
    end
    def test_element
      Abaqus::Element.bind(@m)
      e = Abaqus::Element::S3.new(1,1,2,3)
      assert_equal(1, @m.elements.size)
      assert_equal(e, @m.elements[1])
      assert_equal(e, Abaqus::Element[1])
    end
  end

end

