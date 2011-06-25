
module Abaqus
  module Inp
    module_function
    def parse_command(line)
      unless line =~ /^\*/
        raise ArgumentError,"given argument (#{line}) seems not to be command."
      end
      cmd, *ops = line.upcase.split(/,/).map{|x| x.strip}
      opt = {}
      ops.each do |str|
        key,val = * str.split(/\s*=\s*/,2)
        if val
          opt[key] = val
        else
          opt[key] = true
        end
      end
      return cmd, opt
    end

    def parse_data(io)
      while line = io.gets
        line.strip!
        next if line[0,2] == "**"
        break if line[0,1] == "*"
        yield line
      end
      line
    end
  end
end

if $0 == __FILE__
  require 'test/unit'
  require 'flexmock/test_unit'
  class TestInpParseCommand < Test::Unit::TestCase

    def test_it_returns_keyword_in_uppercase_as_first_retval
      res, opt = Abaqus::Inp.parse_command("*keyword")
      assert_equal("*KEYWORD", res)
    end
    def test_it_can_treat_blank_contained_keyword
      res, opt = Abaqus::Inp.parse_command("*multi word keyword")
      assert_equal("*MULTI WORD KEYWORD",res)
    end
    def test_option_was_returned_as_Hash
      res, opt = Abaqus::Inp.parse_command("*keyword, opt")
      assert_instance_of(Hash, opt)
    end
    def test_option_with_out_equal_contains_true_as_value
      res, opt = Abaqus::Inp.parse_command("*keyword, dummy, opt, dummy2")
      assert(opt["OPT"])
    end
    def test_option_with_equal_contains_R_value
      res, opt = Abaqus::Inp.parse_command("*keyword, key=value")
      assert_equal("VALUE", opt["KEY"])
    end
  end
end

