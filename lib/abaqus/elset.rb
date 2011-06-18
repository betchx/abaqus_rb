
module Abaqus
  class Elset < Array
    @@known_set = {}
    def Elset.[](name)
      @@known_set[name.upcase]
    end
    def Elset.clear
      @@known_set.clear
    end
    def initialize(name, *args)
      unless name.instance_of?(String)
        raise ScriptError, "First argument of Elset.new must be Elset name (instance of String) "
      end
      @@known_set[name.upcase] = self
      super(*args)
    end

    def Elset.parse(head,body)
      # argument check
      #head
      raise ArgumentError,"body is required" unless body
      keyword, *ops = head.strip.split(/\s*,\s*/)
      unless keyword =~ /\*ELSET/i then
        raise ArgumentError,
          "Wrong keyword. *ELSET was expected, but #{keyword} was given"
      end
      name = nil
      generate = false
      ops.each do |option|
        key,val=option.upcase.split(/\s*=\s*/,2)
        case key
        when "ELSET"
          name = val
        when "GENERATE"
          generate = true
        end
      end
      if name.nil?
        raise ArgumentError, "ELSET option was not given"
      end
      set = Abaqus::Elset.new(name)
      if generate
        body.each do |line|
          next if line[0,2] == "**"
          return line.strip if line[0,1] == "*"
          a = line.split(/,/)
          case a.size
          when 3
            b,e,s = * a.map{|x| x.to_i}
          when 2
            b,e = * a.map{|x| x.to_i}
            s = 1
          else
            raise ArgumentError,"Each line must have 2 or 3 items."
          end
          b.step(e,s){|i| set << i}
        end
      else
        body.each do |line|
          next if line[0,2] == "**"
          return line.strip if line[0,1] == "*"

          set << line.split(/,/).map{|x| x.to_i}
          set.flatten!
          set.sort!
          set.uniq!
        end
      end
      # file ended
      return nil
    end
  end
end


if $0 == __FILE__

  require 'test/unit'
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
    end
    def teardown
      Abaqus::Elset.clear
    end

    def test_parse_without_raised
      assert_nothing_raised{
        Abaqus::Elset.parse(@cmd, "")
      }
    end
    def test_parse_register_new_elset
      Abaqus::Elset.parse(@cmd, "")
      assert_instance_of(Abaqus::Elset, Abaqus::Elset[@name])
    end
    def test_count_of_elset_must_be_same
      Abaqus::Elset.parse(@cmd, "3,4")
      assert_not_nil(Abaqus::Elset[@name])
      assert_equal(2, Abaqus::Elset[@name].size)
    end
    def test_parse_must_finish_when_new_keyword_appears
      body = <<-NNN
10, 20, 30
*NSET, NSET=hoge
5,6,7,8,9
      NNN
      Abaqus::Elset.parse(@cmd, body)
      assert_equal([10,20,30], Abaqus::Elset[@name])
    end
    def test_parse_must_return_new_kyword_without_newline
      body = <<-NNN
1,2,3
*KEYWORD
      NNN
      res = Abaqus::Elset.parse(@cmd,body)
      assert_equal("*KEYWORD",res)
    end
    def test_raise_ArgumentError_if_ELSET_parameter_was_not_given
      assert_raise(ArgumentError){
        Abaqus::Elset.parse("*Elset", "")
      }
    end
    def test_raise_ArgumentError_if_keyword_is_not_Elset
      assert_raise(ArgumentError){
        Abaqus::Elset.parse("*NSET","")
      }
    end
    def test_raise_ArgumentError_if_body_was_not_given
      assert_raise(ArgumentError){
        Abaqus::Elset.parse(@cmd,nil)
      }
    end

    def test_parse_handle_multiline_body
      body = <<-KKK
10, 11, 12, 13, 14, 15, 16,17
20, 21, 22,23,24,25
      KKK
      res = [10,11,12,13,14,15,16,17,20,21,22,23,24,25]
      Abaqus::Elset.parse(@cmd,body)
      assert_equal(res, Abaqus::Elset[@name])
    end
    def test_generate_option_with_two_column
      Abaqus::Elset.parse( "*elset, elset=gene, generate", "1,5")
      assert_equal([1,2,3,4,5],Abaqus::Elset["gene"])
    end
    def test_generate_option_with_three_column
      Abaqus::Elset.parse("*elset, elset=g3,generate","1,7,2")
      assert_equal([1,3,5,7], Abaqus::Elset["g3"])
    end
  end
end

