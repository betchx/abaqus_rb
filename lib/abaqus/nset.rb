pos = "abaqus" #File.dirname(__FILE__)
require pos + '/inp'
module Abaqus
  class Nset < Array
    extend Inp
    @@all = {}
    def self.[](name)
      @@all[name.upcase]
    end
    def self.clear
      @@all.clear
    end
    def self.size
      @@all.size
    end
    def initialize(name, *args)
      unless name.instance_of?(String)
        raise ScriptError, "First argument of Nset.new must be set name of String class"
      end
      @name = name.upcase
      old = @@all[@name]
      @@all[@name] = self
      super(*args)
      if old
        self << old
        self.flatten!
      end
    end
    attr_reader :name
    def Nset.parse(head, body)
      keyword, opt = parse_command(head)
      unless keyword == "*NSET"
        raise ArgumentError,
          "wrong keyword of #{keyword} was given for Nset.parse"
      end
      name = opt["NSET"]
      if name.nil? | name.empty?
        raise ArgumentError, "Nset name was not given."
      end
      instance = opt["INSTANCE"]
      if instance
        if opt["GENERATE"]
          # generate option was given
          line_parser = lambda do |arg|
            f, t, s = * arg.split(/,/).map{|x| x.to_i}
            s ||= 1
            a = []
            f.step(t,s){|i| a << sprintf("%s.%d",instance, i)}
            a
          end
        else
          line_parser = lambda do |arg|
            arg.chomp(",").split(/,/).map{|x| "#{instance}.#{x.to_i}"}
          end
        end
      else
        if opt["GENERATE"]
          # generate option was given
          line_parser = lambda do |arg|
            a = []
            if arg.strip =~ /^\s*\d+\s*,/
              f, t, s = * arg.split(/,/)
              s ||= 1
              f.to_i.step(t.to_i, s.to_i){|i| a << i}
            else
              n, f, x, t, s = * arg.split(/[,.]/)
              s ||= 1
              n.upcase!
              f.to_i.step(t.to_i, s.to_i){|i| a << sprintf("%s.%d", n, i)}
            end
            a
          end
        else
          line_parser = lambda do |arg|
            if arg.strip =~ /^\d+\s*,/
              arg.chomp(",").split(/,/).map{|x| x.to_i}
            elsif arg.strip =~ /^\d+$/
              [arg.to_i]
            else
              arg.chomp(",").upcase.split(/,/).map{|x| x.strip}
            end
          end
        end
      end
      arr = []
      line = parse_data(body) do |str|
        line_parser[str].each do |item|
          # check: the item is a previously defined nset name or not.
          case item
          when Integer
            arr << item
          when String
            if @@all.include?(item)
              arr << @@all[item]
            else
              arr << item
            end
          end
        end
      end
      ns = Nset.new(name)
      ns << arr.flatten.sort_by{|x| x.to_s.split('.').pop.to_i}.uniq
      ns.flatten!
      return line, ns
    end
  end
end

if $0 == __FILE__
  require 'test/unit'
  require 'flexmock/test_unit'
  class TestNsetBasic < Test::Unit::TestCase
    def setup
      @name = "nodeSet"
      @ns = Abaqus::Nset.new(@name)
    end
    def teardown
      Abaqus::Nset.clear
    end
    def test_acccess
      assert_equal(@ns, Abaqus::Nset[@name])
    end
    def test_name
      assert_equal(@name.upcase, @ns.name)
    end
  end
  class TestNsetParseNormal < Test::Unit::TestCase
    def setup
      @name = "newSet"
      @cmd = "*NSET, NSET=#{@name}"
      @body = flexmock("NSetBody")
      @stop = "*TERMINAL"
      @body.should_receive(:gets).times(4).and_return(
        (1..8).to_a.join(",")+",",
        (9..16).to_a.join(",")+",",
        "17,18,19",
        @stop
      )
      @ans = (1..19).to_a
      @res, @ns = Abaqus::Nset.parse(@cmd,@body)
    end
    def teardown
      Abaqus::Nset.clear
    end

    def test_it_must_return_next_command_as_first_retval
      assert_equal(@stop, @res)
    end
    def test_it_must_return_Nset_as_second_retval
      assert_instance_of(Abaqus::Nset, @ns)
    end
    def test_ns_must_have_same_name_in_command
      assert_equal(@name.upcase, @ns.name)
    end
    def test_parsed_Nset_should_be_accessable_from_Nset_with_square_branket
      assert_not_nil(Abaqus::Nset[@name])
    end
    def test_pasred_result_must_must_contain_node_given_node_ids
      assert_equal(@ans, @ns)
    end
  end
  class TestNsetParseWithGenerateOption < Test::Unit::TestCase
    def setup
      @name = "withGene"
      @cmd = "*NSET, nset=#{@name}, generate"
      @stop="*ELEMENT"
      @body = flexmock("Gane")
      @ans = (1..19).to_a
      @argset = nil
    end
    def setarg(*args)
      @argset = true
      @body.should_receive(:gets).at_most.times(args.size).and_return(*args)
    end
    def parse(cmd = @cmd, body = @body)
      setarg "1,19,1",@stop unless @argset
      @res, @ns = Abaqus::Nset.parse(cmd, body)
    end
    def teardown
      Abaqus::Nset.clear
    end
    def test_it_must_return_next_command_in_uppercase_as_first_retval
      parse
      assert_equal(@stop.upcase,@res)
    end
    def test_it_must_return_Nset_as_second_retval
      parse
      assert_instance_of(Abaqus::Nset, @ns)
    end
    def test_second_retval_must_have_given_nset_name_in_uppercase
      parse
      assert_equal(@name.upcase, @ns.name)
    end
    def test_created_nset_can_be_accessed_via_Nset_with_name
      parse
      assert_same(@ns, Abaqus::Nset[@name])
    end
    def test_created_nset_must_contain_specified_list_of_nodes
      parse
      assert_equal(@ans, @ns)
    end
    def test_data_line_without_step_generate_sequential_ids
      setarg "1,10", @stop
      parse
      assert_equal( (1..10).to_a, @ns)
    end
    def test_data_line_with_no_one_step_generate_intervaled_data
      setarg "2,20,2", @stop
      parse
      assert_equal((1..10).map{|x| x*2}, @ns)
    end
  end

  class TestParseFull < Test::Unit::TestCase
    def setup
      @body = flexmock("Gane")
    end
    def teardown
      Abaqus::Nset.clear
    end
    def test_fullname
      @body.should_receive(:gets).twice.and_return("Part1-1.3 , Part1-1.5",nil)
      Abaqus::Nset.parse("*nset, nset=full",@body)
      assert_equal(["Part1-1.3","Part1-1.5"], Abaqus::Nset["full"])
    end
    def test_with_instance
      @body.should_receive(:gets).twice.and_return( " 1 , 3 , 5 , 7", nil)
      Abaqus::Nset.parse("*nset, nset=full-in, instance=Inst",@body)
      assert_equal(%w(INST.1 INST.3 INST.5 INST.7), Abaqus::Nset["full-in"])
    end
    def test_gen_with_instance
      @body.should_receive(:gets).twice.and_return(" 1, 7, 2", nil)
      Abaqus::Nset.parse("*nset, nset=gi, generate, instance=ig", @body)
      assert_equal(%w(IG.1 IG.3 IG.5 IG.7), Abaqus::Nset["gi"])
    end
    def test_gen_with_fullname
      @body.should_receive(:gets).twice.and_return("IX.1, IX.7, 2", nil)
      Abaqus::Nset.parse("*nset, nset=fgi, generate", @body)
      assert_equal(%w(IX.1 IX.3 IX.5 IX.7), Abaqus::Nset["fgi"])
    end
  end


  class TestParseInpByCAE < Test::Unit::TestCase
    def setup
      key = "*Nset, nset=RailA, instance=Stringers-1\n"
      str = flexmock("inp"){|m|
	m.should_receive(:gets).and_return(
	  "42,  43,  44,  45,  46,  47,  48,  49,  50,  51,  52,  53,  54,  55,  56,  57\n",
	  "58,  59,  60,  61,  62,  63,  64,  65,  66,  67,  68,  69,  70,  71,  72,  73\n",
	  "74,  75,  76,  77,  78,  79,  80,  81,  82, 377, 378, 379, 380, 381, 382, 383\n",
	  "384, 385, 386, 387, 388, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398, 399\n",
	  "400, 401, 402, 403, 404, 405, 406, 407, 408, 409, 410, 411, 412, 413, 414, 415\n",
	  "416,\n",
	  "*Elset, elset=RailA, instance=Stringers-1, generate\n",
	  nil
	)
      }
      @ans = [    42,  43,  44,  45,  46,  47,  48,  49,
	50,  51,  52,  53,  54,  55,  56,  57,  58,  59,
	60,  61,  62,  63,  64,  65,  66,  67,  68,  69,
	70,  71,  72,  73,  74,  75,  76,  77,  78,  79,
	80,  81,  82,                     377, 378, 379,
       380, 381, 382, 383, 384, 385, 386, 387, 388, 389,
       390, 391, 392, 393, 394, 395, 396, 397, 398, 399,
       400, 401, 402, 403, 404, 405, 406, 407, 408, 409,
       410, 411, 412, 413, 414, 415, 416].map{|x| "STRINGERS-1.#{x}"}
      @key, @ns = Abaqus::Nset::parse(key,str)
    end

    def test_ns
      assert_equal(@ans, @ns)
    end

  end
end
