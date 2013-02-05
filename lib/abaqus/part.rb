
dir = "abaqus" #File::dirname(__FILE__)
require dir + '/node'
require dir + '/nset'
require dir + '/element'
require dir + '/elset'
require dir + '/binder'
require dir + '/inp'

unless defined?(ABAQUS_PART_RB)
  ABAQUS_PART_RB = true

  module Abaqus
    class Part
      extend Inp
      @@all = UpcaseHash.new
      def initialize(name)
        @nodes = {}
        @elements = {}
        @nsets = UpcaseHash.new
        @elsets = UpcaseHash.new
        @properties = UpcaseHash.new
        @name = name.upcase
        @@all[name.upcase] = self
      end
      def self.[](name) @@all[name.upcase] end
      def self.clear() @@all.clear end
      def self.size() @@all.size end

      attr_reader :nodes, :elements, :nsets, :elsets, :name, :properties

      BindTargets = [Node, Element, Nset, Elset, Property]

      def bind_all
        BindTargets.each do |klass|
          klass.bind(self)
        end
      end
      def release_all
        BindTargets.each do |klass|
          klass.release
        end
      end
      def with_bind
        bind_all
        yield
        release_all
      end

      def self.parse(line, body)
        line
        keyword, opt = parse_command(line) 
        raise unless  keyword == "*PART"
        name = opt['NAME']
        part = Part.new(name)
        line = parse_data(body) # move to contents
        part.with_bind do
          until keyword == "*END PART"
            keyword, opt = parse_command(line)
            klass = KnownKeywords[keyword]
            if klass
              line, *arg = klass.parse(line, body)
            else
              line = parse_data(body){} #skip unknown keyword
            end
          end
        end
        return line
      end
    end
  end


end
