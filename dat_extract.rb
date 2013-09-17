#! /usr/bin/ruby
# coding: Shift_JIS

INC = /INCREMENT +(\d+) SUMMARY/ ;
FIN = /THE ANALYSIS HAS BEEN COMPLETED/;
FIN2 = /ANALYSIS COMPLETE/;

require 'pp'

require 'abaqus'

class File
  def skip
    begin
      wk = self.gets
      return nil unless wk
      $step += 1 if wk =~ /  S T E P  /
    end while wk.strip.empty?
    #$stderr.puts "File::Next '#{wk}'"
    return wk.strip

  end
end

class ErrorDumper
  def initialize(file = nil)
    if file
      @file = file
      @out = nil
    else
      @out = $defout
    end
  end

  def <<(arg)
    @out ||= open(@file, "wb")  or raise "Could not open error file #{@file} for output."

    at = caller.first
    unless  at == @prev
      @prev = at
      @out.puts at
    end
    case arg
    when String  # to supress quatations.
      @out.puts arg
    else
      PP.pp(arg, @out)
    end

    return self
  end
end

dumper = ErrorDumper.new("#{File::basename($0,'.rb')}.err")



ARGV.each do |file|
  $stderr.puts "DAT file: #{file}"
  base = File::basename(file,".dat")
  dir = File::dirname(file)
  Dir.chdir(dir)

  # get model information from input file
  inp = Dir[base + ".inp"].shift # To get actual case of input file
  $stderr.puts "INP file: #{inp}"
  f = open(file)
  model = Abaqus::parse(open(inp))
  outs = {}
  nodes = {}
  elems = {}

  # Create output directory
  Dir::mkdir(base) unless FileTest::directory?(base)

  # reset step counter
  $step = 0

  # Skip to first increment
  begin
    line = f.gets
    raise if line.nil?
  end until line =~ INC

  while line
    inc = line.scan(INC).flatten[0]
    4.times{ line = f.gets }
    t = line.split.pop.to_f

    $stderr.print sprintf("\rinc %5d  time: %g", inc, t)


    line = f.skip
#    $stderr.puts "time: #{t}: #{line} @ #{f.lineno}"
    raise unless line =~ /E L E M E N T   O U T P U T/ ;

    while (line = f.skip)
      #$stderr.puts line
      break if line =~/N O D E   O U T P U T/;
      break if line =~ INC
      break if line =~ FIN
      break if line =~ FIN2
      #      $stderr.puts "line : '#{line}'"
      raise "#{line} @ #{f.lineno}" unless line =~ /THE FOLLOWING TABLE IS PRINTED AT THE/;
      elname = line.split.pop
      until (wk = f.gets.strip).empty?
        elname = wk.strip.split.pop
      end
      name = elname
      raise "wrong name of '#{elname}' at #{t} line: #{f.lineno}" if elname =~/ /
      point = nil
      heads = nil
      case line
      when /AT THE INTEGRATION POINTS/
        name = elname + "-ip"
        point = :integ
        heads = f.skip.strip.split[4..-1]
      when /AT THE CENTROID OF THE ELEMENT/
        name = elname + "-ec"
        point = :center
        heads = f.skip.strip.split[3..-1]
      when /AT THE NODE OF/ # maybe element nodes
        name = elname + "-en"
        point = :elnode
        heads = f.skip.strip.split[4..-1]
      else
        raise "Not supported output type for elset #{elname}"
      end
      out = outs[name]
      if out.nil?
        out = open("#{base}/#{name}.csv","w")
        outs[name] = out

        if model.elsets[elname]
          elems[elname] = model.elsets[elname].sort
        elsif model.steps[$step-1].elsets[elname]
          elems[elname] = model.steps[$step-1].elsets[elname].sort
        else
          raise "Element set '#{elname}' does not found"
        end
        out.print "time"
        heads.each do |h|
          elems[elname].each do |e|
            case point
            when :integ
              1.upto(4) do |pt|
                [1,5].each do |sec|
                  out.print ",#{h}@e#{e}-pt#{pt}-sp#{sec}"
                end
              end
            when :center
              [1,5].each do |sec|
                out.print ",#{h}@e#{e}-sp#{sec}"
              end
            when :elnode
              nodes = model.elements(e).nodes.sort
              nodes.each do |n|
                [1,5].each do |sec|
                  out.print ",#{h}@e#{e}-n#{n}-sp#{sec}"
                end
              end
            end
          end
        end
        out.puts
      end
      1.times{f.gets}
      out.print t
      line = f.skip
      case point
      when :integ, :elnode
        if line =~ /ALL VALUES/
          (heads.size * elems[elname].size * 8).times{out.print ",0"}
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
      when :center
        if line =~ /ALL VALUES/
          (heads.size * elems[elname].size * 2).times{out.print ",0"}
          out.puts
        else
          res = {}
          begin
            eid, sec, *val = line.split
            res[[eid, sec]] = val
          end until (line = f.gets.strip).empty?
          res.keys.sort.each do |k|
            out.print ",#{res[k]}"
          end
          out.puts
          5.times{f.gets}
        end
      end
    end

    break if line =~ FIN
    break if line =~ FIN2
    next if line =~ INC
    unless line =~ /N O D E/
      $stderr.puts line
    end
    line = f.skip

    begin
      break if line =~ INC
      break if line =~ FIN
      break if line =~ FIN2
      #$stderr.puts line
      wk = line
      begin
        name = wk.split.pop
        wk = f.gets.strip
      end until wk.empty?
      raise if name =~ / /;
      out = outs[name]
      line = f.skip
      heads = line.strip.split[2..-1]
      unless out
        out = open("#{base}/#{name}.csv","w")
        outs[name] = out
        if model.nsets[name]
          nodes[name] = model.nsets[name].sort
        elsif model.steps[$step-1].nsets[name]
          nodes[name] = model.steps[$step-1].nsets[name].sort
        else
          raise "Node set '#{name}' does not found"
        end
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
          if res[nid].nil?
            dumper << "nid" << nid << "res" << res << "res[nid]" << res[nid] << "res[nid.to_i]" << res[nid.to_i]
            raise "Any result for NID:#{nid} was not found in 'res'"
          end
          out.print ",#{res[nid].join(',')}"
        end
        out.puts
        6.times{f.gets}
      end
    end while line = f.skip

    break if line =~ FIN
    break if line =~ FIN2

  end

  outs.each do |k,out|
    out.close
  end

  f.close

  $stderr.puts

end


$stderr.puts "Finished.  Press Enter to exit"
$stdin.gets

