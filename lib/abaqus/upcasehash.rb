
unless defined?(ABAQUS_UPCASEHASH_RB)
  ABAQUS_UPCASEHASH_RB = true
  module Abaqus
    # Hash with key must be upcase
    class UpcaseHash < Hash
      alias :actref :[]
      def [](key)
        actref(key.to_s.upcase)
      end
    end
  end
end

