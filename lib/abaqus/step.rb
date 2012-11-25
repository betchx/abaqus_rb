

dir = "abaqus" #File::dirname(__FILE__)
require dir + '/inp'
require dir + "/bc"
require dir + "/load"

unless defined?(Abaqus::Model)
  require dir + '/binder'
  [Abaqus::Bc, ABAQUS::Load].each do |target|
    Abaqus::Binder.inject_bind_methods(target)
  end
end

module Abaqus
  class Step
    @@all = []
    extend Inp
    def self.parse(head,body)
      key, opts = parse_command(head)
      unless key == "*STEP"
        raise ArgumentError,
          "Step.parse needs *STEP keyword but #{key} was given"
      end
      name = opts["NAME"] || "Step-#{@@all.size + 1}"
      step = self.new(name)
      # step has no data line
      line = parse_data(body)
      iostack = [body]
      until iostack.empty?
       body = iostack.pop
       while line
        key, opts = parse_command(line)
        case key
        when "*INCLUDE"
          fname = opts['INPUT']
          iostack.push body
          $stderr.puts "Including #{fname} in step #{name} "
          body = open(fname)
          line = parse_data(body)
        when "*DYNAMIC"
          step.analysis_type = "dynamic"
          dynamic_data_line_called =false
          line = parse_data(body){|arg|
            dt,dur,min_inc, max_inc = arg.split(/,/).map{|x| (x&&x.strip.length >0)?(x.to_f):nil}
            if dynamic_data_line_called
              raise ArgumentError,"Only one data line is allowed for *Dynamic"
            end
            dynamic_data_line_called = true
            step.dt = dt
            step.dur = dur
            step.min_inc = min_inc
            step.max_inc = max_inc
          }
          step.error_check(opts)
        when "*END STEP"
          break
        when "*BOUNDARY"
          Bc.with_bind(step) do
            line = Bc.parse(line, body)
          end
        when "*CLOAD","*DLOAD"
          Load.with_bind(step) do
            line = Load.parse(line, body)
          end
        when "*NSET"
          Nset.with_bind(step) do
            line,ns = Nset.parse(line,body)
          end
        when "*ELSET"
          Elset.with_bind(step) do
            line, es = Elset.parse(line,body)
          end
        else
          line = parse_data(body)
        end
       end
      end
      return line, step
    end
    def dynamic?() analysis_type == "dynamic" end
    def bcs
      @bcs||={}
    end
    def loads
      @loads ||= {}
    end
    def nsets
      @nsets ||= {}
    end
    def elsets
      @elsets ||= {}
    end
    def initialize(name)
      upcase_hash = Hash.new
      upcase_hash.instance_eval{ |o|
        alias :actref :[]
        def [](key)
          actref(key.upcase)
        end
      }
      @name = name
      @nsets = upcase_hash.clone
      @elsets = upcase_hash.clone
      @@all << self
      @num = @@all.size
      @analysis_type = "not dynamic"
    end
    attr :num
    attr :dur, true
    attr :dt, true
    attr :min_inc, true
    attr :max_inc, true
    attr :analysis_type, true
    attr_reader :is_direct, :is_explicit
    alias :direct? :is_direct
    alias :explicit? :is_explicit
    def error_check(opts)
      #error check
      unless dur
        raise ArgumentError,"duration of step must be specified"
      end
      if dur.to_f <= 0.0
        raise ArgumentError,"duration must be possitive value"
      end
      @is_direct = opts['DIRECT']
      if (@is_explicit = opts['EXPLICIT'] )then
        if min_inc
          raise ArgumentError,"minimum time increment is not available in explicit dynamic"
        end
        if direct?
          unless dt
            raise ArgumentError,'time increment is required for direct dynamic'
          end
        else
          if dt
            raise ArgumentError,'time incremnt must not be specified for explicit dynamic analysis without direct keyword'
          end
        end
      else
        # Implicit dynamic
        unless dt
          raise ArgumentError,'time incement is required for implicit dynamic' unless dt
        end
      end
    end
  end
end

