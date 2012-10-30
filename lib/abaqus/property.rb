
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

    # �e�G�������g�Ƀv���p�e�B�ւ̎Q�Ƃ�ǉ�����D
    # �������d���Ǝv����̂ŁC�K�v�Ȃ���΍s��Ȃ�
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

    # �e�G�������g�ɑS�v���p�e�B�ւ̎Q�Ƃ�ǉ�����D
    # �������d���Ǝv����̂ŁC�K�v�Ȃ���΍s��Ȃ�
    def self.expand_to_element
      @@all.each do |key,value|
        value.expand_to_element
      end
    end

  end
end
