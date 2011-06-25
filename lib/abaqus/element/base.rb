
unless defined?(ABAQUS_ELEMENT)
  ABAQUS_ELEMENT= true

module Abaqus
  class Element
    extend Inp
    # Element.new recieve type and create it
    def self.new(*args,&blocks)
      if args.empty?
        return super
      end
      case args[0]
      when String
        element_type = args.shift
        return obtain_element_class(element_type).new(*args,&blocks)
      else
        return super
      end
    end
    def initialize
      raise "Abaqus::Element.new is not allowed. Use sub classes instead"
    end
    attr_reader :i, :nodes

  p pos = File.dirname(File.dirname(__FILE__))
  #require pos + '/node'
  require pos + '/elset'
  require pos + '/inp'
    @@all = Abaqus::GlobalModel.elements
    @@maxid = 0
    def self.clear
      @@all.clear
      Abaqus::Elset.clear
      @@maxid = 0
    end
    def self.bind(model)
      @@all = model.elements
      @@maxid = @@all.keys.max || 0
    end
    def self.release
      @@maxid = @@all.keys.max || 0
    end
    def self.bind_with(model)
      bind(model)
      yield
      release
    end

    def assign(eid,element)
      @@all[eid] = element
      @@maxid = eid if @@maxid < eid
    end
    private :assign

    def self.nextid
      @@maxid + 1
    end

      @@all = {}
    def self.[](i)
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
    def self.const_missing(name)
      obtain_element_class(name)
    end

    def self.size
      @@all.size
    end

    @@KnownElements = Hash.new
    def self.regist(type,klass)
      @@KnownElements[type] = klass
    end

    def self.inherited(klass)
      unless klass.name.empty?
        # automatically registered for static class definition.
        type = klass.name.split(/::/).pop
        regist(type,klass)
      end
    end

    def self.obtain_element_class(type)
      @@KnownElements[type] || create_new_element_class(type)
    end

    BasicElementMap = []
    def self.regist_as_basic_element(re,klass)
      BasicElementMap << [re, klass]
    end

    def self.obtain_base_class(eltype)
      BasicElementMap.each do |re,klass|
        if re.match(eltype)
          return klass
        end
      end
      return nil
    end

    def self.create_new_element_class(type)
      base = obtain_base_class(type)
      if base.nil?
        raise NameError, "undefinde constant or Unknown element type: #{type}"
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
      regist(type,klass)
    end

    def self.parse(line, io)
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
      else
        es = []
      end

      klass = obtain_element_class(type)
      cmd = ""
      eids = []
      cmd = parse_data(io) do |line|
        es << klass.parse(line,io).i
      end
      es.flatten!
      es.sort!
      es.uniq!
      return cmd,es.to_a
    end
  end
end

end


if $0 == __FILE__
  require 'test/unit'
  require 'flexmock/test_unit'
  $static_name = "StaticElement"
  module Abaqus
    class Element
      unless defined?(StaticElement)
      class StaticElement < Element
        extend Inp
        def type
          $static_name
        end
        def initialize(i,*a)
          @i = i
          @nodes = [*a].flatten
          assign(i, self)
        end
        def self.parse(head,body)
          i, *a = head.split(/,/).map{|x| x.to_i}
          self.new(i, *a)
        end
        Element::BasicElementMap << [/^StaticElement/i,self]
      end
      end
    end
  end
  class TestElementBase < Test::Unit::TestCase

    # Initial
    def test_initially_Element_has_empty_list
      assert_equal(0,Abaqus::Element.size)
    end

    # test of inherited
    def test_static_subclass_definition
      assert_not_nil(Abaqus::Element::StaticElement)
    end
    def test_Static_subclass_can_be_obtained
      assert_same(Abaqus::Element::StaticElement,
                  Abaqus::Element.obtain_element_class($static_name))
    end
    def test_basic_elment
      assert( Abaqus::Element::BasicElementMap.find([/./,Abaqus::Element::StaticElement]))
    end

  end
  class TestElsetBase < Test::Unit::TestCase
    def setup
      @elset_name = "TestElements"
      @cmd = "*element, type=#{$static_name}, elset=#{@elset_name}"
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

