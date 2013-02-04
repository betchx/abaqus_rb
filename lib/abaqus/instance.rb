


dir = "abaqus" #File::dirname(__FILE__)
require dir + '/part'
require dir + '/upcasehash'

unless defined?(ABAQUS_INSTANCE_RB)
  ABAQUS_INSTANCE_RB = true

  module Abaqus
    class Instance
      @@all = UpcaseHash.new
      def initialize(name, part)
        @name = name
        @part = part
        @delta = [0.0, 0.0, 0.0]
        @rotate  0.0
        @rot_a = [0.0, 0.0, 0.0]
        @rot_b = [0.0, 0.0, 0.0]
      end
      def set_translate(dx, dy, dz)
      end

      def set_rotate(*arr)
        @rotate[0] = arr[6]
        0.upto(2) do |i|
          @rot_a[i] = arr[i]
          @rot_b[i] = arr[3+i]
        end
      end

      def self.parse(line, body)
        keyword, options = parse_command(line)
        unless keyword == "*INSTANCE"
          raise ArgumentError, "Instance keyword is required"
        end
        name = options['NAME']
        part = options['PART']
        instance = self.new(name, part)
        @@all[name] = instance
        line = pare_data(body) do |str|
          arr = str.split(/,/).map{|x| x.to_f}
          case arr.size
          when 7
            set_rotate(arr)
          when 3
            set_translate(arr[0], arr[1]||0.0, arr[2]||0.0)
          end
        end
        return line
      end

      attr_reader name, part
      def pos(nid)

      end
    end
  end

end
