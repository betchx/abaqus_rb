

dir = File::dirname(__FILE__)
require dir + '/inp'

unless defined?(Abaqus::Model)
  require dir + '/binder'
  [Abaqus::BC, ABAQUS::Load].each do |target|
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
      while line
        key, opts = parse_command(line)
        case key
        when "*END STEP"
          break
        when "*BOUNDARY"
          BC.with_bind(step) do
            line = BC.parse(line, body)
          end
        when "*CLOAD","*DLOAD"
          Load.with_bind(step) do
            line = Load.parse(line, body)
          end
        else
          line = parse_data(body)
        end
      end
      return line, step
    end
    def bcs
      @bcs||={}
    end
    def loads
      @loads ||= {}
    end
    def initialize(name)
      @name = name
      @@all << self
      @num = @@all.size
    end
  end
end

