

module Abaqus
  class Step
    def initialize(name)
      @name = name
      @@all << self
      @num = @@all.size
    end
  end
end

