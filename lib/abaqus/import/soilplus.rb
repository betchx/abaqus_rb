unless defined?(ABAQUS_IMPORT_SOILPLUS)
  ABAQUS_IMPORT_SOILPLUS = true

  require 'abaqus'

  class Abaqus
    class SoilPlus
      def initialize(model)
        @model = model
      end
      class Card
        Parser = Hash.new
        def initialize(str)
          @line = str
          @key = str[0,4]
          if parser = Prarser[@key]
            parser[str]
          end
        end
        attr_reader :key
        def [](index, next_index=nil)
          if next_index
            raise ArgumentError unless next_index - index = 1
            return @line[index*8,8] + @line[next_inedx*8, 8]
          end
          return @line[index*8,8]
        end
        def f(index, next_index = nil)
          next_index ||= index + 1
          self[index] + self[next_index]
        end
        Parser["GRID"] = Proc.new{|str|
          ss = StringScan
        }
      end

      def get_list(io)
        list = []
        while line = io.gets
          case line
          when /^\*/
            # comment
          when /^\+/
            # continued line
            list.last += line.chomp
          else
            list.push line.chomp
          end
        end
        return list.map{|x| Card.new(x)}
      end
      def parse(io)
        @model.with_bind do
          get_list(io).each do |card|
          case card.key
          when "GRID"
            # node
            Node.new(card[1].to_i,   # node ID
                     card[2,3].to_f, # X coodinate
                     card[4,5].to_f, # Y coodinate
                     card[6,7].to_f) # Z coodinate
          when "SPC "
            BC.new(card[1].to_i,  # node id
                   card[2].strip.to_enum(:each_char).map{|x| x.to_i}, #array of dof
                   0.0,  # value
                   nil ) # options 
          when "MPC "
            #skip
          when "MAT"
            name = card[1]
            # need to construct Abaqus string
            cont = "*ELASTIC\n"
            cont += card[3,4] + "," + card[2]
            cont += "\n*DENSITY\n"
            cont += card[8]
            Material.new(name, cont)
          when "QPLR"
            # Four node shell element
            eid = card[1].to_i
            Element.new("S4", 
                        eid,
                        card[5].to_i,
                        card[6].to_i,
                        card[7].to_i,
                        card[8].to_i)
            es = Elset[card[3]] ||  Elset.new(card[3])
            es << eid
          when "BAR "



          end
        end
      end
      def get_line(io)
        line = "*"
        while line =~ /^\*/
          line = io.gets
        end
        return line
      end
    end
    def Abaqus.load_SoilPlus(io, name="soilplus_model")
      model = Model.new(name)
      Node.reset_converter


    end
  end
end
