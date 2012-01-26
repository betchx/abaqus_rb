
unless defined?(Abaqus::Element::S8)

require 'abaqus/element_base'

module Abaqus
  class Element
    class S8 < Element
      def initialize(i,n1,n2,n3,n4,n5,n6,n7,n8)
        @nodes = [n1,n2,n3,n4,n5,n6,n7,n8]
        @i = i
        assign(i,self)
      end
      def [](n)
        if n < 8 && n > -9
          @nodes[n]
        else
          raise ArgumentError,"index must be between 0 and 3"
        end
      end
      def type
        "S8"
      end
      def nodes
        @nodes
      end
      def self.parse_line(line,io)
        i,*a = * line.chomp(",").split(/,/).map{|x| x.to_i}
        while line =~ /,\s*$/
          line = io.gets
          if line
            line.strip!
            a << line.chomp(",").split(/,/).map{|x| x.to_i}
          end
        end
        a.flatten!
        if a.size > 8
          raise RuntimeError, "Too many nodes are given (n=#{a.size})"
        end
        if a.size < 8
          raise RuntimeError, "Given nodes are not enough (n=#{a.size})"
        end
        return i,*a
      end
      def self.parse(line,io)
        self.new(*parse_line(line,io))
      end
      Element::BasicElementMap << [/^S8/,self]
    end
  end
end

end


if $0 == __FILE__
  require 'test/unit'
  require 'flexmock/test_unit'
  class TestElementS8 < Test::Unit::TestCase

    def setup
      @s8id = 1
      @s8nodes = [1,2,3,6,9,8,7,4]
      @s8rid = 2
      @s8rnodes = [11,12,13,16,19,18,17,14]
    end
    def s8
      Abaqus::Element::S8.new(@s8id,*@s8nodes)
    end
    def s8r
      Abaqus::Element.new("S8R",@s8rid,*@s8rnodes)
    end
    def teardown
      Abaqus::Element.clear
    end

    def test_S8_new_keeps_order_of_node
      e = s8

      8.times do |i|
        assert_equal(@s8nodes[i],e[i])
      end
    end

    def test_S8_must_raise_ArgumentError_if_node_id_query_with_over_3
      e = s8
      assert_raise(ArgumentError){
        e[8]
      }
    end
    def test_S8_must_raise_ArgumentError_if_node_id_query_with_less_than_minus_5
      e = s8
      assert_raise(ArgumentError){
        e[-9]
      }
    end
    def test_S8_nid_minus_8_must_return_same_value_of_idx_0
      e = s8
      assert_equal(e[0],e[-8])
    end
    def test_S8_type_must_return_S8
      assert_equal("S8",s8.type)
    end
    def test_S8_new_added_to_ElementList
      e = s8
      assert_equal(e, Abaqus::Element[@s8id])
    end

    def test_S8_new_increase_Element_size
      assert_equal(0, Abaqus::Element.size)
      s8
      assert_equal(1, Abaqus::Element.size)
    end

    def test_S8_i_must_return_created_id
      assert_equal(@s8id, s8.i)
    end

    def test_S8_nodes_method_returns_array_of_nodes_with_its_order
      assert_equal(@s8nodes,s8.nodes)
    end

    def test_modificaion_of_retval_of_S8_nodes_should_not_affect_original
      e = s8
      a = s8.nodes
      a[0] = 8
      s8.nodes[1] = 9
      assert_not_equal(a[0],e[0])
      assert_not_equal(9, e[1])
      assert_equal(1,e[0])
      assert_equal(2,e[1])
    end
    def test_stored_element_must_be_original_type_S8
      e = s8
      assert_equal(e, Abaqus::Element[@s8id])
    end

    def test_creating_first_element_of_eid_1_changes_nextid_to_2
      s8
      assert_equal(2, Abaqus::Element.nextid)
    end
    def test_creation_of_first_element_change_nextid_for_the_elements_id_plus_1
      eid = rand(7438)
      e = Abaqus::Element::S8.new(eid, * @s8nodes )
      assert_equal(eid+1,Abaqus::Element.nextid)
    end
  end
  class TestS8Parse < Test::Unit::TestCase
    def setup
      @cmd = "*Element, type=S8"
      # element node definition allows up to 16 items or 80 characters 
      # for each line
      @str1 = <<-NNN
1, 1,2,3,6,9,8,7,4
      NNN
      @str2 = <<-KKK
2, 1, 2, 3, 6, 9, 8, 7, 4
3, 7, 8, 9,12,15,14,13,10
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

    def test_created_element_type_must_be_S8_for_one_elements
      try_parse(@cmd,@str1)
      e = Abaqus::Element[@ids[0]]
      assert_equal("S8",e.type)
    end
    def test_created_element_has_same_element_of_given
      try_parse(@cmd,@str1)
      assert_equal([1,2,3,6,9,8,7,4],Abaqus::Element[1].nodes)
    end
    def test_parsed_result_of_S8R5_will_be_subclass_of_S8
      try_parse("*ELEMENT,type=S8R5",@str1)
      assert_kind_of(Abaqus::Element::S8,Abaqus::Element[1])
    end
    def test_parsed_result_of_S8R5_must_have_type_of_S8R5
      try_parse("*ELEMENT,type=S8R5",@str1)
      assert_equal("S8R5", Abaqus::Element[1].type)
    end
    def test_multiple_definition_of_element_can_be_parsed_correctly
      cmd = "*Element,Elset=A,type=S8"
      second_cmd = "*Element,elset=B,type=S8R"
      ans = [
        "1,  1, 2, 3, 6, 9, 8, 7, 4",
        "2, 11,12,13,16,19,18,17,14",
        second_cmd,
        "3, 21,22,23,26,29,28,27,24",
        "4, 31,32,33,36,39,38,37,34",
        nil
      ]
      body = flexmock("mIO")
      body.should_receive(:gets).at_most.times(ans.size).and_return(*ans)
      res,ids = Abaqus::Element.parse(cmd,body)
      assert_equal([1,2], ids)
      assert_equal(second_cmd,res)
      assert_equal(2, Abaqus::Element.size)
      ns = []
      ns[0] = [1,2,3,6,9,8,7,4]
      1.upto(3) do |i|
        ns[i] = ns[0].map{|x| x+i*10}
      end
      assert_equal(ns[0], Abaqus::Element[1].nodes)
      assert_equal("S8", Abaqus::Element[1].type)
      assert_equal(ns[1], Abaqus::Element[2].nodes)
      assert_equal("S8", Abaqus::Element[2].type)
      res2,ids2 = Abaqus::Element.parse(res,body)
      assert_nil( res2)
      assert_equal([3,4],ids2)
      assert_equal(4, Abaqus::Element.size)
      assert_equal(ns[0], Abaqus::Element[1].nodes)
      assert_equal("S8", Abaqus::Element[1].type)
      assert_equal(ns[1], Abaqus::Element[2].nodes)
      assert_equal("S8", Abaqus::Element[2].type)
      assert_equal(ns[2], Abaqus::Element[3].nodes)
      assert_equal("S8R", Abaqus::Element[3].type)
      assert_equal(ns[3], Abaqus::Element[4].nodes)
      assert_equal("S8R", Abaqus::Element[4].type)
    end
    def test_not_sequential_eid_can_be_handed
      cmd = "*Element,Elset=A,type=S8"
      ans = [
        "2, 9,10,11,12,13,14,15,16",
        "1, 1,2,3,4,5,6,7,8",
        "4, 25,26,27,28,29,30,31,32",
        "3, 17,18,19,20,21,22,23,24",
        nil
      ]
      body = flexmock("mIO")
      body.should_receive(:gets).at_most.times(ans.size).and_return(*ans)
      res,ids = Abaqus::Element.parse(cmd,body)
      assert_nil(res)
      assert_equal([2,1,4,3].sort, ids.sort)
      assert_equal(4, Abaqus::Element.size)
    end
  end
  class TestElementS8ParseForNonSequencialEID < Test::Unit::TestCase
    def setup
      cmd = "*ELEment, type=S8, elset=A"
      body = flexmock("mIO")
      body.should_receive(:gets).times(5).and_return(
         "   1, 1,2,3,4,5,6,7,8\n",
          " 11,11,12,13,14,15,16,17,18 \n",
          "101,21,22,23,24,25,26,27,28\n",
          "102,31,32,33,34,35,36,37,38\n",
          nil
      )
      @eids = [1,11,101,102]
      @nextid = 103
      $res,$ids = Abaqus::Element.parse(cmd, body)
    end
    def test_nil_was_returned
      assert_nil($res)
    end
    def test_eids
      assert_equal(@eids.sort, $ids.sort)
    end
    def test_size
      assert_equal(@eids.size, Abaqus::Element.size)
    end
    def test_nextid
      assert_equal(@nextid, Abaqus::Element.nextid)
    end
  end
  class TestElsetInS8 < Test::Unit::TestCase
    def setup
      @elset_name = "TestElements"
      @cmd = "*element, type=S8, elset=#{@elset_name}"
      @str1 = <<-NNN
1, 1,2,3,6,9,8,7,4
      NNN
      @str2 = <<-KKK
2, 1,2,3,6,9,8,7,4
3, 10, 11,12, 15, 18, 17, 16, 13
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

end


