
dir ="abaqus" # File::dirname(__FILE__)
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

    # 各エレメントにプロパティへの参照を追加する．
    # 処理が重いと思われるので，必要なければ行わない
    def expand_to_element(model = GlobalModel)
      mat = model.materials[@material]
      model.elsets[@name].each do |x|
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

    # 各エレメントに全プロパティへの参照を追加する．
    # 処理が重いと思われるので，必要なければ行わない
    def self.expand_to_element
      @@all.each do |key,value|
        value.expand_to_element
      end
    end

  end
end
