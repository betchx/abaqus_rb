
unless defined?(ABAQUS_ELEMENT)
  ABAQUS_ELEMENT= true

  pos = 'abaqus' #File.dirname(File.dirname(__FILE__))
  #require pos + '/node'
  require pos + '/elset'
  require pos + '/inp'

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
          if args[0] =~  /\./
            # full name case
            return super
          end
          element_type = args.shift
          klass = obtain_element_class(element_type)
          return klass.new(*args,&blocks)
        else
          return super
        end
      end
      def initialize
        raise "Abaqus::Element.new is not allowed. Use sub classes instead"
      end
      attr_reader :i, :nodes
      attr_accessor :property, :material

      @@all = {}
      @@maxid = 0
      def self.clear
        @@all.clear
        Abaqus::Elset.clear
        @@maxid = 0
      end
=begin
      def self.bind(model)
        @@all = model.elements
        @@maxid = @@all.keys.max || 0
      end
      def self.release
        @@all = GlobalModel.elements
        @@maxid = @@all.keys.max || 0
      end
      def self.bind_with(model)
        bind(model)
        yield
        release
      end
=end

      def assign(eid,element)
        @@all[eid] = element
        case eid
        when Integer
          @@maxid = eid if @@maxid < eid
        end
      end
      private :assign

      def self.nextid
        @@maxid + 1
      end

      def self.[](i)
        case i
        when Integer
          if i < 0
            raise IndexError,"Negative element ID is not allowed"
          end
          if i == 0
            raise IndexError,"EID 0 is not allowed now"
          end
          if i > @@all.size
            raise IndexError,"Specified id of #{i} exeeds used id number"
          end
        end
        @@all[i] # or raise IndexError,"EID #{i} is not used."
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
      def self.known_elements
        @@KnownElements.keys
      end

      def self.inherited(klass)
        unless klass.name.empty?
          # automatically registered for static class definition.
          type = klass.name.split(/::/).pop
          regist(type,klass)
        end
      end

      def self.obtain_element_class(eltype)
        res = @@KnownElements[eltype]
        if res.nil?
          if Abaqus.dummy_enabled?
            res = Abaqus::Element::Dummy
          else
            res = create_new_element_class(eltype)
           end
        end
        res
      end

      BasicElementMap = []

      def self.obtain_base_class(eltype)
        BasicElementMap.each do |re,klass|
          if re.match(eltype)
            return klass
          end
        end
        return nil
      end

      def self.create_new_element_class(eltype)
        base = obtain_base_class(eltype)
        if base.nil?
          raise NameError, "undefinde constant or Unknown element type: #{eltype}"
        end
        klass = Class.new(base){|m|
          class_variable_set(:@@type, eltype)
          def m.type
            return class_variable_get(:@@type)
          end
          def type
            return self.class.type#.class_variable_get(:@@type)
          end
        }
        # assign name of new class
        const_set(eltype,klass)
        # no automatic register support for dynamic class definition
        regist(eltype,klass)
      end

      def self.parse(line, io, dbg = false)
        cmd, ops = parse_command(line)
        unless cmd == "*ELEMENT"
          raise ArgumentError,"Element.parse can handle *element keyword only."
        end

        eltype = ops["TYPE"]
        unless eltype
          raise ArgumentError,"element type must be specified."
        end

        es = nil
        setname = ops["ELSET"]
        if setname
          es = Abaqus::Elset[setname] || Abaqus::Elset.new(setname)
        else
          es = []
        end

        klass = obtain_element_class(eltype)
        puts "#{eltype}:#{klass}" if dbg
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
  class TestElsetBaseParse < Test::Unit::TestCase
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
      assert_not_nil(@cmd)
      assert_not_nil(@str1)
      try_parse(@cmd,@str1)
    end
    def test_elset_was_created_after_parse_with_elset_option
      assert_not_nil(@cmd)
      assert_not_nil(@str1)
      try_parse(@cmd,@str1)
      assert(Abaqus::Elset[@elset_name])
    end
    def test_elset_must_contain_created_element_id_by_parse
      assert_not_nil(@cmd)
      assert_not_nil(@str1)
      try_parse(@cmd,@str1)
      assert_equal([1], Abaqus::Elset[@elset_name])
    end
  end

end

