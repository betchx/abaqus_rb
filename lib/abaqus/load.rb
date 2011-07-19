
unless defined?(ABAQUS_LOAD_RB)
  ABAQUS_LOAD_RB = true

  require "abaqus/inp"

  module Abaqus
    class Load
      extend Inp
      def self.parse(head,body)
        parse_data(body)
      end
    end
  end

end
