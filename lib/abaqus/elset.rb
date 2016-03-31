
require 'abaqus/inp'

module Abaqus
  class Elset < Array
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
        raise ScriptError, "First argument of Elset.new must be Elset name (instance of String) "
      end
      old = @@all[name.upcase]
      @@all[name.upcase] = self
      super(*args)
      if old
        self << old
        self.flatten!
      end
    end

    def Elset.parse(head,body)
      raise ArgumentError,"body is required" unless body
      keyword, ops = parse_command(head)
      unless keyword =~ /\*ELSET/i then
        raise ArgumentError,
          "Wrong keyword. *ELSET was expected, but #{keyword} was given"
      end
      unless name = ops["ELSET"]
        raise ArgumentError, "ELSET option was not given"
      end
      set = Abaqus::Elset.new(name)
      if instance = ops["INSTANCE"]
        if ops["GENERATE"]
          cmd = parse_data(body) do |line|
            b,e,s = line.strip.chomp(",").split(/,/)
            s ||= 1
            b.to_i.step(e.to_i, s.to_i){|i| set << "#{instance}.#{i}"}
          end
        else
          cmd = parse_data(body)do |line|
            set << line.chomp(",").split(/,/).map{|x| "#{instance}.#{x.strip}"}
          end
        end
      else
        if ops["GENERATE"]
          cmd = parse_data(body) do |line|
            if line.strip =~ /^\d+\s*,/
              b,e,s = *line.strip.chomp(",").split(/,/)
              s ||= 1
              b.to_i.step(e.to_i, s.to_i){|i| set << i}
            else
              n,b,x,e,s = *line.strip.chomp(",").split(/[,.]/)
              s ||= 1
              n.upcase!
              b.to_i.step(e.to_i, s.to_i){|i| set << "#{n}.#{i}"}
            end
          end
        else
          cmd = parse_data(body)do |line|
            if line.strip =~ /^\d+\s*,/
              set << line.chomp(",").split(/,/).map{|x| x.to_i}
            elsif line.strip =~ /^\d+$/
              set << line.to_i
            else
              set << line.chomp(",").upcase.split(/,/).map{|x| x.strip}
            end
          end
        end
      end
      set.flatten!
      set.sort!
      set.uniq!
      return cmd
    end
  end
end


if $0 == __FILE__

  require 'test/unit'
  require 'flexmock/test_unit'

  class TestElset < Test::Unit::TestCase

    def setup
    end
    def teardown
      Abaqus::Elset.clear
    end

    def test_new_without_name_must_raise_Script_error
      assert_raise(ScriptError){
        Abaqus::Elset.new([0,1,2,3])
      }
    end

    def test_elset_can_access_by_its_name
      test_name = "hoge"
      set = Abaqus::Elset.new(test_name)
      assert_same(set, Abaqus::Elset[test_name])
    end
  end


  class TestElsetParse < Test::Unit::TestCase
    def setup
      @name = "TestSet"
      @cmd = "*ELSET, ELSET=#{@name}"
      @body = flexmock("mIO")
    end
    def teardown
      Abaqus::Elset.clear
    end

    def test_parse_without_raised
      @body.should_receive(:gets).once.and_return(nil)
      assert_nothing_raised{
        Abaqus::Elset.parse(@cmd, @body)
      }
    end
    def test_parse_register_new_elset
      @body.should_receive(:gets).once.and_return(nil)
      Abaqus::Elset.parse(@cmd, @body)
      assert_instance_of(Abaqus::Elset, Abaqus::Elset[@name])
    end
    def test_count_of_elset_must_be_same
      @body.should_receive(:gets).twice.and_return("3,4",nil)
      Abaqus::Elset.parse(@cmd, @body)
      assert_not_nil(Abaqus::Elset[@name])
      assert_equal(2, Abaqus::Elset[@name].size)
    end
    def test_parse_must_finish_when_new_keyword_appears
      @body.should_receive(:gets).twice.and_return(
        "10, 20, 30\n",
        "*NSET, NSET=hoge\n",
        "5,6,7,8,9\n",
        nil
      )
      Abaqus::Elset.parse(@cmd, @body)
      assert_equal([10,20,30], Abaqus::Elset[@name])
    end
    def test_parse_must_return_new_kyword_without_newline
      @body.should_receive(:gets).twice.and_return(
        "1,2,3\n",
        "*KEYWORD\n",nil
      )
      res = Abaqus::Elset.parse(@cmd,@body)
      assert_equal("*KEYWORD",res)
    end
    def test_raise_ArgumentError_if_ELSET_parameter_was_not_given
      @body.should_receive(:gets).never
      assert_raise(ArgumentError){
        Abaqus::Elset.parse("*Elset", @body)
      }
    end
    def test_raise_ArgumentError_if_keyword_is_not_Elset
      @body.should_receive(:gets).never
      assert_raise(ArgumentError){
        Abaqus::Elset.parse("*NSET",@body)
      }
    end
    def test_raise_ArgumentError_if_body_was_not_given
      assert_raise(ArgumentError){
        Abaqus::Elset.parse(@cmd,nil)
      }
    end

    def test_parse_handle_multiline_body
      @body.should_receive(:gets).times(3).and_return(
        "10, 11, 12, 13, 14, 15, 16,17",
        "20, 21, 22,23,24,25",nil
      )
      res = [10,11,12,13,14,15,16,17,20,21,22,23,24,25]
      Abaqus::Elset.parse(@cmd,@body)
      assert_equal(res, Abaqus::Elset[@name])
    end
    def test_generate_option_with_two_column
      @body.should_receive(:gets).twice.and_return("1,5",nil)
      Abaqus::Elset.parse( "*elset, elset=gene, generate", @body)
      assert_equal([1,2,3,4,5],Abaqus::Elset["gene"])
    end
    def test_generate_option_with_three_column
      @body.should_receive(:gets).twice.and_return("1 , 7 , 2",nil)
      Abaqus::Elset.parse("*elset, elset=g3,generate",@body)
      assert_equal([1,3,5,7], Abaqus::Elset["g3"])
    end
    def test_fullname
      @body.should_receive(:gets).twice.and_return("Part1-1.3 , Part1-1.5",nil)
      Abaqus::Elset.parse("*elset, elset=full",@body)
      assert_equal(["Part1-1.3","Part1-1.5"], Abaqus::Elset["full"])
    end
    def test_with_instance
      @body.should_receive(:gets).twice.and_return( " 1 , 3 , 5 , 7", nil)
      Abaqus::Elset.parse("*elset, elset=full-in, instance=Inst",@body)
      assert_equal(%w(INST.1 INST.3 INST.5 INST.7), Abaqus::Elset["full-in"])
    end
    def test_gen_with_instance
      @body.should_receive(:gets).twice.and_return(" 1, 7, 2", nil)
      Abaqus::Elset.parse("*elset, elset=gi, generate, instance=ig", @body)
      assert_equal(%w(IG.1 IG.3 IG.5 IG.7), Abaqus::Elset["gi"])
    end
    def test_gen_with_fullname
      @body.should_receive(:gets).twice.and_return("IX.1, IX.7, 2", nil)
      Abaqus::Elset.parse("*elset, elset=fgi, generate", @body)
      assert_equal(%w(IX.1 IX.3 IX.5 IX.7), Abaqus::Elset["fgi"])
    end


  end
end

