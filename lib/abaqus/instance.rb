
dir = "abaqus" #File::dirname(__FILE__)
require dir + '/part'
require dir + '/upcasehash'
require dir + '/quaternion'

unless defined?(ABAQUS_INSTANCE_RB)
  ABAQUS_INSTANCE_RB = true

  module Abaqus
    class Instance
      extend Inp
      @@all = UpcaseHash.new
      def initialize(name, part)
        @name = name
        @part = part
        @node_cache = Hash.new
        @elem_cache = Hash.new

        @@all[name.upcase] = self
        @delta = Vector[0.0, 0.0, 0.0]
        @rot_a = Vector[0.0, 0.0, 0.0]
        @rot_b = Vector[0.0, 0.0, 0.0]
      end
      attr_reader :name, :part
      def self.[](name) @@all[name.upcase] end
      def self.clear() @@all.clear end
      def self.size() @@all.size end

      def set_translate(dx, dy, dz)
        @delta.x = dx
        @delta.y = dy
        @delta.z = dz
      end

      def set_rotate(*arr)
        @angle = arr[6]
        0.upto(2) do |i|
          @rot_a[i] = arr[i]
          @rot_b[i] = arr[3+i]
        end
        @ax = @rot_b - @rot_a
        @rotator = Quaternion.RotationInDegree(@angle,@ax.x, @ax.y, @ax.z)
      end

      def make_full(item)
         "#{name}.#{item}"
      end

      def element(eid)
        full_name = make_full(eid)
        elm = @element_cache[eid]
        unless elm
          if base = part.elements[eid]
            nodes = base.nodes.map{|nid| make_full(nid)}
            elm = base.class.new(full_name, *nodes)
            @element_cache[eid] = elm
          end
        end
        elm
      end
      def node(nid)
        nd = @node_cache[nid]
        unless nd
          full_name = make_full(nid)
          base = part.nodes[nid]
          if base
            v = pos(nid)
            nd = Node.new(full_name, v.x, v.y, v.z)
            @node_cache[nid] = nd
          end
        end
        nd
      end

      def self.parse(line, body)
        keyword, options = parse_command(line)
        unless keyword == "*INSTANCE"
          raise ArgumentError, "Instance keyword is required"
        end
        name = options['NAME'].upcase
        part_name = options['PART']
        part = @@parent.parts[part_name]
        instance = self.new(name, part)

        #setup nset
        Nset.with_bind(parent) do
          part.nsets.each do |key, nset|
            full_name = name + "." + key
            ns = Nset.new(full_name)
            nset.each do |node|
              ns << "#{name}.#{node}"
            end
          end
        end
        #setup Elset
        Elset.with_bind(parent) do
          part.elsets.each do |key, elset|
            full_name = name + "." + key
            es = Elset.new(full_name)
            elset.each do |elm|
              es << "#{name}.#{elm}"
            end
          end
        end

        line = parse_data(body) do |str|
          arr = str.split(/,/).map{|x| x.to_f}
          case arr.size
          when 7
            instance.set_rotate(*arr)
          when 3
            instance.set_translate(arr[0], arr[1]||0.0, arr[2]||0.0)
          else
            raise ScriptError, "Something wrong. arr is #{arr.inspect}"
          end
        end
        return line
      end

      def pos(nid)
        n = part.nodes[nid]
        v0 = Vector[n.x, n.y, n.z] + @delta
        if @rotator
          v1 = v0 - @rot_a
          v2 = @rotator * v1.to_q * @rotator.conj
          v3 = v2.as_v + @rot_a
          return v3
        else
          return v0
        end
      end
    end
  end

end
