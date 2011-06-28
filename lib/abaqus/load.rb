
unless defined?(ABAQUS_LOAD_RB)
  ABAQUS_LOAD_RB = true

  dir = File::dirname(__FILE__)
  require dir + "/inp"

  module Abaqus
    class Load
      extend Inp
      def self.parse(head,body)
        parse_data(body)
      end
    end
  end

end
