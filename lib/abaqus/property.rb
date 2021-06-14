#coding: utf-8
dir ="abaqus" # File::dirname(__FILE__)
require dir + "/inp"

module Abaqus
  class Property
    @@method = "properties"
    def initialize(elset_name, key, material, *values)
      @name = elset_name
      @material = material
      @key = key
      @values = values
      @@all[@name] = self
    end
    attr_reader :name, :material, :key

    def [](i)
      return @values[i]
    end

    extend Inp
    def self.parse(head, body)
      key, opts = parse_command(head)
      elset_name = opts["ELSET"]
      raise "No elset was given (#{head})" if elset_name.nil?
      mat = opts["MATERIAL"] || ""
      vals = []
      res = parse_data(body) do |str|
        vals << str.split(/\s*,\s*/)
      end
      # do not flat
      prop = self.new(elset_name, key, mat, *vals)
      return res, prop
    end

    # Add reference for property into each element if nessesary.
    # (It may be heavy operation)
    def expand_to_element(model = GlobalModel)
      mat = model.materials[@material]
      elset = model.elsets[@name]
      if elset.nil?
        raise "Element set with name of #{@name} was not found"
      end
      elset.each do |x|
        e = model.elements[x]
        unless e.property.nil?
          prop = e.property
          raise "Multiple Property definition for Element ID #{x} \n" +
            "  OLD property: #{prop.neme} (#{prop.material}) \n" +
          "  NEW property: #{@name} (#{@material}) \n"
        else
          e.property = self
          e.material = mat
        end
      end
    end

    # Add reference for property into each element if nessesary.
    # (It may be heavy operation)
    def self.expand_to_element
      @@all.each do |key,value|
        value.expand_to_element
      end
    end

  end
end
