
dir = "abaqus" #File::dirname(__FILE__)
require dir + 'node'
require dir + 'nset'
require dir + 'element'
require dir + 'elset'
require dir + '/binder'

unless defined?(ABAQUS_PART_RB)
  ABAQUS_PART_RB = true

  module Abaqus
    class Part


      def initialize(name)
        @nodes = {}
        @elements = {}
        @nsets = UpcaseHash.new
        @elsets = UpcaseHash.new
        @name = name
      end
      attr_reader nodes, elements, nsets, elsets, name

      BindTargets = [Node, Element, Nset, Elset]

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
    end
  end


end
