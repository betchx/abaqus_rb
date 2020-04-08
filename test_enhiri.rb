require 'pp'
class Base
  def self.inherited(klass)
    p klass.inspect
  end
end

class Sub < Base
  CONST = "constant"
end




