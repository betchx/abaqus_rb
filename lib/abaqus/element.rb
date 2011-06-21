
require 'abaqus/node'
require 'abaqus/elset'
require 'abaqus/inp'

module Abaqus
  class Element
    extend Inp
    @@all = {}
    @@maxid = 0
    def Element.clear
      @@all.clear
      @@maxid = 0
    end
    def initialize
      raise "Abaqus::Element.new is not allowed. Use sub classes instead"
    end

    def assign(i,e)
      @@all[i] = e
      @@maxid = i if @@maxid <i
    end
    private :assign

    def Element.nextid
      @@maxid + 1
    end

    def Element.[](i)
      if i < 0
        raise IndexError,"Negative element ID is not allowed"
      end
      if i == 0
        raise IndexError,"EID 0 is not allowed now"
      end
      if i > @@all.size
        raise IndexError,"Specified id of #{i} exeeds used id number"
      end
      @@all[i] or raise IndexError,"EID #{i} is not used."
    end

    def Element.size
      @@all.size
    end

    @@KnownElements = Hash.new
    def Element.register(type,klass)
      @@KnownElements[type] = klass
    end

    def Element.inherited(klass)
      unless klass.name.empty?
        # automatically registered for static class definition.
        type = klass.name.split(/::/).pop
        register(type,klass)
      end
    end

    class S4 < Element
      def initialize(i,n1,n2,n3,n4)
        @nodes = [n1,n2,n3,n4]
        @i = i
        assign
      end
      attr_reader :i
      def [](n)
        if n < 4 && n > -5
          @nodes[n]
        else
          raise ArgumentError,"index must be between 0 and 3"
        end
      end
      def assign
        super(@i,self)
      end
      private :assign

      def type
        "S4"
      end
      def nodes
        @nodes
      end
      def S4.parse_line(line)
        i,n1,n2,n3,n4, n5 = * line.split(/,/)
        if n5
          raise RuntimeError, "Too many nodes are given"
        end
        unless n4
          raise RuntimeError, "Given nodes are not enough"
        end
        return i,n1,n2,n3,n4
      end
      def S4.parse(line,io)
        e = self.new(*parse_line(line).map{|x| x.to_i})
        e.i
      end
      #Element.register("S4",self)
    end
    class S4R < S4
      def type
        "S4R"
      end
      #Element.register("S4R",self)
    end

    def Element.obtain_element_class(type)
      @@KnownElements[type] || create_new_element_class(type)
    end

    BasicElementMap = [
      [/^S4/,S4],
    ]

    def Element.obtain_base_class(type)
      BasicElementMap.each do |re,klass|
        if re.match(type)
          return klass
        end
      end
      return nil
    end

    def Element.create_new_element_class(type)
      base = obtain_base_class(type)
      if base.nil?
        raise ArgumentError, "Unknown element type was specified"
      end
      klass = Class.new(base){|m|
        @@type = type
        def type
          return @@type
        end
      }
      # assign name of new class
      const_set(type,klass)
      # no automatic register support for dynamic class definition
      register(type,klass)
    end

    def Element.parse(line, io)
      cmd, ops = parse_command(line)
      unless cmd == "*ELEMENT"
        raise ArgumentError,"Element.parse can handle *element keyword only."
      end

      type = ops["TYPE"]
      unless type
        raise ArgumentError,"element type must be specified."
      end

      es = nil
      setname = ops["ELSET"]
      if setname
        es = Abaqus::Elset[setname] || Abaqus::Elset.new(setname)
      end

      klass = obtain_element_class(type)
      cmd = ""
      eids = []
      while line = io.gets
        cmd = line.strip
        case cmd
        when /^\*\*/
          next
        when /^\*/
          break
        else
          eids << klass.parse(line,io)
        end
      end
      if es
        es << eids
        es.flatten!
        es.uniq!
      end
      cmd = nil if line.nil?
      return cmd,eids
    end

  end
end

if $0 == __FILE__
  require 'test/unit'
  require 'flexmock/test_unit'
  class TestElement < Test::Unit::TestCase

    def setup
      @nodes = [1,2,3,4,5,6,7,8]
      @nodes.each do |i|
        z = (i-1) / 4
        y = ((i-1) / 2) % 2
        x = (i-1) % 2
        Abaqus::Node.new(i,x,y,z)
      end
    end
    def s4
      @s4id = 1
      Abaqus::Element::S4.new(@s4id,1,2,4,3)
    end
    def s4r
      @s4rid = 2
      Abaqus::Element::S4R.new(@s4rid,1,2,4,3)
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

    ######S4

    def test_S4_new_keeps_order_of_node
      e = s4

      assert_equal(1,e[0])
      assert_equal(2,e[1])
      assert_equal(4,e[2])
      assert_equal(3,e[3])
    end
    def test_S4_must_raise_ArgumentError_if_node_id_query_with_over_3
      e = s4
      assert_raise(ArgumentError){
        e[4]
      }
    end
    def test_S4_must_raise_ArgumentError_if_node_id_query_with_less_than_minus_5
      e = s4
      assert_raise(ArgumentError){
        e[-5]
      }
    end
    def test_S4_nid_minus_4_must_return_same_value_of_idx_0
      e = s4
      assert_equal(e[0],e[-4])
    end
    def test_S4_type_must_return_S4
      e = s4
      assert_equal("S4",e.type)
    end
    def test_S4_new_added_to_ElementList
      e = s4
      assert_equal(e, Abaqus::Element[@s4id])
    end

    def test_S4_new_increase_Element_size
      assert_equal(0, Abaqus::Element.size)
      e = s4
      assert_equal(1, Abaqus::Element.size)
    end

    def test_S4_i_must_return_created_id
      e = s4
      assert_equal(@s4id, e.i)
    end

    def test_S4_nodes_method_returns_array_of_nodes_with_its_order
      e = s4
      assert_equal([1,2,4,3],e.nodes)
    end

    def test_modificaion_of_retval_of_S4_nodes_should_not_affect_original
      e = s4
      a = s4.nodes
      a[0] = 8
      s4.nodes[1] = 9
      assert_not_equal(a[0],e[0])
      assert_not_equal(9, e[1])
      assert_equal(1,e[0])
      assert_equal(2,e[1])
    end
    def test_stored_element_must_be_original_type__S4
      e = s4
      assert_equal(e, Abaqus::Element[@s4id])
    end

    def test_at_first_nextid_should_be_one
      assert_equal(1, Abaqus::Element.nextid)
    end
    def test_creating_first_element_of_eid_1_changes_nextid_to_2
      Abaqus::Element::S4.new(1, 1,2,4,3)
      assert_equal(2, Abaqus::Element.nextid)
    end
    def test_creation_of_first_element_change_nextid_for_the_elements_id_plus_1
      eid = rand(7438)
      e = Abaqus::Element::S4.new(eid, 1, 2,4,3)
      assert_equal(eid+1,Abaqus::Element.nextid)
    end

    ### S4R
    def test_S4R_type_must_return_S4R
      e = s4r
      assert_equal("S4R",e.type)
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
  class TestS4Parse < Test::Unit::TestCase
    def setup
      @cmd = "*Element, type=S4"
      @str1 = <<-NNN
1, 1,2,4,3
      NNN
      @str2 = <<-KKK
2, 1,2,4,3
3, 5,6,8,7
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
      body.should_receive(:gets).and_return(*args)
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
      assert_equal("S4",e.type)
    end
    def test_created_element_has_same_element_of_given
      try_parse(@cmd,@str1)
      assert_equal([1,2,4,3],Abaqus::Element[1].nodes)
    end
    def test_parsed_result_of_S4R5_will_be_subclass_of_S4
      try_parse("*ELEMENT,type=S4R5",@str1)
      assert_kind_of(Abaqus::Element::S4,Abaqus::Element[1])
    end
    def test_parsed_result_of_S4R5_must_have_type_of_S4R5
      try_parse("*ELEMENT,type=S4R5",@str1)
      assert_equal("S4R5", Abaqus::Element[1].type)
    end
    def test_parse_raise_ArgumentError_when_unknown_type_was_given
      assert_raise(ArgumentError){
        Abaqus::Element.parse("*ElemEnt, type=Zero",@str1)
      }
    end
    def test_multiple_definition_of_element_can_be_parsed_correctly
      cmd = "*Element,Elset=A,type=S4"
      second_cmd = "*Element,elset=B,type=S4R"
      ans = [
        "1, 1,2,4,3",
        "2, 5,6,8,7",
        second_cmd,
        "3, 1,2,6,5",
        "4, 3,4,8,7",
        nil
      ]
      body = flexmock("mIO")
      body.should_receive(:gets).and_return(*ans)
      res,ids = Abaqus::Element.parse(cmd,body)
      assert_equal([1,2], ids)
      assert_equal(second_cmd,res)
      assert_equal(2, Abaqus::Element.size)
      assert_equal([1,2,4,3], Abaqus::Element[1].nodes)
      assert_equal("S4", Abaqus::Element[1].type)
      assert_equal([5,6,8,7], Abaqus::Element[2].nodes)
      assert_equal("S4", Abaqus::Element[2].type)
      res2,ids2 = Abaqus::Element.parse(res,body)
      assert_nil( res2)
      assert_equal([3,4],ids2)
      assert_equal(4, Abaqus::Element.size)
      assert_equal([1,2,4,3], Abaqus::Element[1].nodes)
      assert_equal("S4", Abaqus::Element[1].type)
      assert_equal([5,6,8,7], Abaqus::Element[2].nodes)
      assert_equal("S4", Abaqus::Element[2].type)
      assert_equal([1,2,6,5], Abaqus::Element[3].nodes)
      assert_equal("S4R", Abaqus::Element[3].type)
      assert_equal([3,4,8,7], Abaqus::Element[4].nodes)
      assert_equal("S4R", Abaqus::Element[4].type)
    end
    def test_not_sequential_eid_can_be_handed
      cmd = "*Element,Elset=A,type=S4"
      ans = [
        "2, 5,6,8,7",
        "1, 1,2,4,3",
        "4, 3,4,8,7",
        "3, 1,2,6,5",
        nil
      ]
      body = flexmock("mIO")
      body.should_receive(:gets).and_return(*ans)
      res,ids = Abaqus::Element.parse(cmd,body)
      assert_nil(res)
      assert_equal([2,1,4,3].sort, ids.sort)
      assert_equal(4, Abaqus::Element.size)
    end
  end
  class TestElementParseForNonSequencialEID < Test::Unit::TestCase
    def setup
      cmd = "*ELEment, type=S4, elset=A"
      body = flexmock("mIO")
      body.should_receive(:gets).and_return(
         "  1, 1, 2, 4, 3",
          " 11, 5, 6, 8, 7",
          "101, 1, 2, 6, 5",
          "102, 3, 4, 8, 7",
          nil
      )
      $res,$ids = Abaqus::Element.parse(cmd, body)
    end
    def test_nil
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
  class TestElset < Test::Unit::TestCase
    def setup
      @elset_name = "TestElements"
      @cmd = "*element, type=S4, elset=#{@elset_name}"
      @str1 = <<-NNN
1, 1,2,4,3
      NNN
      @str2 = <<-KKK
2, 1,2,4,3
3, 5,6,8,7
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
      body.should_receive(:gets).and_return(*strings)
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

