
require 'abaqus/inp'

# Todo: consider "BC group" for easy modification

module Abaqus
  class Bc
    extend Inp
    def initialize(nid, dof, val, ops)
      @i = nid
      @dof = dof
      @value = val
      @params = ops
      @key = ops.to_s
      @@all[@key]  ||= []
      @@all[@key] << self
    end
    FIXED_DOF = {
      "XSYMM" => [1,5,6],
      "YSYMM" => [2,4,6],
      "ZSYMM" => [3,4,5],
      "ENCASTRE" => (1..6).to_a,
      "PINNED" => [1,2,3],
      "XASYMM" => [2,3,4],
      "YASYMM" => [1,3,5],
      "ZASYMM" => [1,2,6],
    }
    def self.parse_label(arg)
      fix_dof = FIXED_DOF[arg.strip.upcase] or raise ArgumentError,"対応していない境界条件ラベル(#{arg})があります．入力ファイルを確認してください"
      fix_dof.map{|x| [x, 0.0]}
    end
    attr_reader :i, :dof, :value, :params, :key
    def self.parse(line, body)
      key,opts = parse_command(line)
      unless key == "*BOUNDARY"
        raise ArgumentError, "#{self} require *BOUNDARY keyword but #{key} was given."
      end
      line = parse_data(body) do |line|
        args = line.split(/\s*,\s*/)
        target_nodes = []
        case args[0]
        when /\d+/
          # node id is given
          target_nodes << args[0].to_i
        else
          nset = Nset[args[0]]
          if nset
            target_nodes = nset.to_a
          end
        end
        args.shift # trash target
        case args.size
        when 1
          # labeled
          bcs = parse_label(args[0])
        when 3
          u1, u2, val = *args
          u2 = u1 if u2.empty?
          bcs = []
          u1.to_i.upto(u2.to_i) do |dof|
            bcs << [dof, val.to_f]
          end
        else
          rase ArgumentError, "*Boundary had wrong data line."
        end
        target_nodes.each do |nid|
          bcs.each do |bc|
            self.new(nid, bc[0], bc[1], opts)
          end
        end
      end
      return line
    end
  end
end



