
dir = File::dirname(__FILE__)
require dir + "/inp"

module Abaqus
  class Property
    @@method = "properties"
    def initialize(elset_name, key, material, *values)
      @name = elset_name
      @material = material
      @values = values
      @@all[@name] = self
    end
    attr_reader :name, :material
    def [](i)
      return @values[i]
    end

    extend Inp
    def self.parse(head, body)
      key, opts = parse_command(head)
      elset_name = opts["ELSET"]
      raise if elset_name.nil?
      mat = opts["MATERIAL"] || ""
      vals = []
      res = parse_data(body) do |str|
        vals << str.split(/\s*,\s*/)
      end
      # do not flat
      prop = self.new(elset_name, key, mat, *vals)
      return res, prop
    end
  end
end
