#! /usr/bin/ruby
# coding: Shift_JIS

INC = /INCREMENT +(\d+) SUMMARY/ ;
FIN = /THE ANALYSIS HAS BEEN COMPLETED/

require 'abaqus'

class File
  def skip
    begin
      wk = self.gets.strip
    end while wk.empty?
#    $stderr.puts "File::Next '#{wk}'"
    return wk
  end
end

ARGV.each do |file|
  f = open(file)
  base = File::basename(file,".dat")

  # get model information from input file
  inp = Dir[base + ".inp"].shift # To get actual case of input file
  model = Abaqus::parse(open(inp))
  outs = {}
  is_integ={}
  nodes = {}
  elems = {}

  # Create output directory
  Dir::mkdir(base) unless FileTest::directory?(base)

  # Skip to first increment
  begin
    line = f.gets
    raise if line.nil?
  end until line =~ INC

  while line
    inc = $1
    4.times{ line = f.gets }
    t = line.split.pop.to_f


    line = f.skip
#    $stderr.puts "time: #{t}: #{line} @ #{f.lineno}"
    raise unless line =~ /E L E M E N T   O U T P U T/ ;

    while (line = f.skip)
      #$stderr.puts line
      break if line =~/N O D E   O U T P U T/;
      break if line =~ INC
      break if line =~ FIN
      #      $stderr.puts "line : '#{line}'"
      raise "#{line} @ #{f.lineno}" unless line =~ /THE FOLLOWING TABLE IS PRINTED AT THE/;
      name = line.split.pop
      name = f.gets.strip if name == "SET"
      raise "wrong name of '#{name}' at #{t} line: #{f.lineno}" if name =~/ /
      out = outs[name]
      heads = f.skip.strip.split[4..-1]
      if out.nil?
        out = open("#{base}/#{name}.csv","w")
        outs[name] = out
        unless model.elsets[name]
          raise "Element set '#{name}' does not found"
        end
        elems[name] = model.elsets[name].sort
        out.print "time"
        heads.each do |h|
          elems[name].each do |e|
            1.upto(4) do |pt|
              [1,5].each do |sec|
                out.print ",#{h}@#{e}-#{pt}-#{sec}"
              end
            end
          end
        end
        out.puts
      end
      2.times{f.gets}
      out.print t
      line = f.skip
      if line =~ /ALL VALUES/
        (heads.size * elems[name].size * 8).times{out.print ",0"}
        out.puts
      else
        res = {}
        begin
          eid, pt, sec, *val = line.split
          res[[eid,pt,sec]] = val
        end until (line = f.gets.strip).empty?
        res.keys.sort.each do |k|
          out.print ",#{res[k]}"
        end
        out.puts
        5.times{f.gets}
      end
    end

    break if line =~ FIN
    next if line =~ INC
    unless line =~ /N O D E/
      $stderr.puts line
    end
    line = f.skip

    begin
      break if line =~ INC
      break if line =~ FIN
      #$stderr.puts line
      name = line.split.pop
      name = f.gets.strip if name == "SET"
      raise if name =~ / /;
      out = outs[name]
      line = f.skip
      heads = line.strip.split[2..-1]
      unless out
        out = open("#{base}/#{name}.csv","w")
        outs[name] = out
        nodes[name] = model.nsets[name] or raise "Node set '#{name}' does not fount"
        out.print "time"
        nodes[name].each do |nid|
          heads.each do |h|
            out.print ",#{h}@#{nid}"
          end
        end
        out.puts
      end
      2.times{f.gets}
      line = f.gets
      if line =~/ALL VALUES IN THIS TABLE ARE ZERO/
        out.print t
        (heads.size * nodes[name].size).times do
          out.print ",0"
        end
        out.puts
      else
        res = {}
        begin
          nid, *values  = line.split
          res[nid.to_i] = values
        end until (line = f.gets.strip).empty?
        out.print t
        nodes[name].each do |nid|
          out.print ",#{res[nid].join(',')}"
        end
        out.puts
        6.times{f.gets}
      end
    end while line = f.skip

    break if line =~ FIN

  end

  outs.each do |k,out|
    out.close
  end

  f.close

end


