
unless defined?(ABAQUS_LOAD_RB)
  ABAQUS_LOAD_RB = true

  require "abaqus/inp"

  module Abaqus
    class Load
      extend Inp
      def initialize(nid)
        @nid = nid
        @vals = {}
      end
      def self.[](nid)
        @@all[nid] ||= new(nid)
      end
      attr_reader :nid
      def add(dof, value)
        @vals[dof.to_i] ||= 0.0
        @vals[dof.to_i] += value.to_f
      end
      def [](dof)
        @vals[dof]
      end
      def dofs
        @vals.keys
      end
      def each
        @vals.each do |content|
          yield content
        end
      end
      def self.parse(head,body)
        key, opts = parse_command(head)
        res = parse_data(body){|arg|
          n, d, v = arg.split(/,/).map{|x| x.strip}
          if sets = parent.class.parent.nsets[n]
            sets.each do |nid|
              self[nid].add d, v
            end
          else
            self[n].add d, v
          end
        }
        res
      end
    end
    class DLoad
      extend Inp
      def initialize(eid, type, *values)
        @eid = eid
        @type = type
        @values = values
      end
      attr_reader :eid, :type, :value

      def self.[](eid)
        @@all[eid]
      end

      def self.parse(head,body)
        key, opts = parse_command(head)
        res = parse_data(body){|arg|
          e, t, *vals = arg.split(/,/).map{|x| x.strip}
          case t
          when /^(TRVEC\d?|TRSHR\d?|EDLD\d?|TRVEC)(NU)?/
            # Add special treatment if it required.
          end
          step = parent
          model = step.class.parent
          set = model.elsets[e]
          unless set.nil?
            set.each do |eid|
              self.new(eid, t, *vals)
            end
          else
            self.new(e, t, *vals)
          end
        }
        res
      end
    end
  end

end
