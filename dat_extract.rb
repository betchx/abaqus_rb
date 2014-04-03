#! /usr/bin/ruby
# coding: Shift_JIS

INC = /INCREMENT +(\d+) SUMMARY/ ;
FIN = /THE ANALYSIS HAS BEEN COMPLETED/;
FIN2 = /ANALYSIS COMPLETE/;

require 'pp'
require 'optparse'
require 'abaqus'

$quiet = false

OptionParser.new do |opt|
  opt.on('-q', '--quiet', "Skip Conformation"){
    $quiet = true
  }

  opt.parse!(ARGV)
end

class File
  def skip
    begin
      wk = self.gets
      return nil unless wk
      redo if wk =~ /OR: \*ORIENTATION USED FOR THIS ELEMENT/
      $step += 1 if wk =~ /  S T E P  /
    end while wk.strip.empty?
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
  $stderr.print "INP file: #{inp}"
  f = open(file)
  model = Abaqus::parse(open(inp))
  outs = {}
  nodes = {}
  fixed_inc = false

  # Create output directory
  Dir::mkdir(base) unless FileTest::directory?(base)

  # reset step counter
  $step = 0

  line = true

  while line
    # Skip to first increment
    begin
      line = f.gets
      if line =~ /FIXED TIME INCREMENTS/
        line = f.gets
        fixed_inc = line.strip.split.pop.to_f
      end
      if line =~ /S T E P +(\d)/
        $step = $1.to_i
        $stderr.puts "\n:Step #{$step}:"
      end
      raise "No increment is found" if line.nil?
    end until line =~ INC


    inc = line.scan(INC).flatten[0].to_i
    4.times{ line = f.gets }

    if fixed_inc
      t = fixed_inc * inc
    else
      t = line.split.pop.to_f
    end
    

    $stderr.print sprintf("\rinc %5d  time: %g", inc, t)


    line = f.skip
    #$stderr.puts "time: #{t}: #{line} @ #{f.lineno}"
    raise "Element Output does not found in #{file} at #{fileno} "  unless line =~ /E L E M E N T   O U T P U T/ ;

    while (line = f.skip)
      break if line =~/N O D E   O U T P U T/;
      break if line =~ INC
      break if line =~ FIN
      break if line =~ FIN2
      break if line =~ /^1\r?\n?/  # Start of step

      #$stderr.puts "line : '#{line}'"
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
      when /AT THE CENTROID OF THE ELEMENT/
        name = elname + "-ec"
        point = :center
      when /AT THE NODE OF/ # maybe element nodes
        name = elname + "-en"
        point = :elnode
      else
        raise "Not supported output type for elset #{elname}"
      end
      heads = f.skip.split(/-/,2).pop.strip.split.map{|x| x.strip}

      out = outs[name]
      if out.nil?
        out = {:name=>name, :time => [], :heads => {}, :data => {}}
        outs[name] = out
      end
      1.times{f.gets}
      out[:time][inc-1] = t
      line = f.skip
      case point
      when :integ, :elnode
        unless line =~ /ALL VALUES/
          begin
            eid, pt, sec, *val = line.strip.split
            heads.each_with_index do |h,i|
              key = [h,eid,pt,sec]
              if out[:data][key].nil?
               out[:data][key] ||= ["0"] * (inc - 1)
               if point == :integ
                 out[:heads][key] = "#{h}@e#{eid}-pt#{pt}-sp#{sec}"
               else
                 out[:heads][key] = "#{h}@e#{eid}-n#{n}-sp#{sec}"
               end
              end
              out[:data][key] << val[i]
            end
          end until (line = f.gets.strip).empty?
          5.times{f.gets}
        end
      when :center
        unless line =~ /ALL VALUES/
          begin
            eid, sec, *val = line.split
            heads.each_with_index do |h,i|
              key = [h,eid,sec]
              if out[:data][key].nil?
                out[:data][key] = ["0"] * (inc - 1)
                out[:heads][key] = "#{h}@e#{eid}-sp#{sec}"
              end
              out[:data][key] << val[i]
            end
          end until (line = f.gets.strip).empty?
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
      break if line =~ /^1\r?\n?/  # Start of step
      wk = line
      begin
        name = wk.split.pop
        wk = f.gets.strip
      end until wk.empty?
      raise if name =~ / /;

      break if name == "subsidiary."  # begining of step

      out = outs[name]
      line = f.skip
      heads = line.strip.split[2..-1]
      unless out
        out = {:name=>name, :time => [t], :heads => {}, :data => {}}
        outs[name] = out
        if model.nsets[name]
          nodes[name] = model.nsets[name].sort
        elsif model.steps[$step-1].nsets[name]
          nodes[name] = model.steps[$step-1].nsets[name].sort
        elsif name =~ /ASSEMBLY_\w+_\w+/
          # need split
          as,pt,gn = name.split(/_/)
          nodes[name] = model.parts[pt].nsets[gn]
        else
          raise "Node set '#{name}' does not found  ( #{file} line #{f.lineno} )"
        end
        nodes[name].each do |nid|
          heads.each do |h|
            out[:heads][[h,nid]] = ",#{h}@#{nid}"
            out[:data][[h,nid.to_s]] = []
          end
        end
      end
      2.times{f.gets}
      line = f.gets
      out[:time] << t unless (out[:time].last - t).abs < (0.01 * t / inc)
      if line =~/ALL VALUES IN THIS TABLE ARE ZERO/
        heads.each do |h|
          out[:data].each do |k,nid|
            out[:data][[h,nid]] << 0.0 if k == h
          end
        end
      else
        res = {}
        begin
          nid, *values  = line.split
          heads.each_with_index do |h,i|
            key = [h,nid]
            if out[:data][key].nil?
              pp out[:data]
              pp key
            end
            out[:data][key] << values[i]
          end
        end until (line = f.gets.strip).empty?
        5.times{f.gets}
      end
    end while line = f.skip

    break if line =~ FIN
    break if line =~ FIN2

  end

  f.close

  #outs.each do |k,out|
  #  out.close
  #end

  outs.each do |name,set|
    keys = set[:data].keys.sort

    open("#{base}/#{name}.csv","w") do |out|
      out.print "time"
      keys.each do |key|
        out.print ",#{set[:heads][key]}"
      end
      out.puts

      set[:time].each_with_index do |t,i|
        out.print t
        keys.each do |key|
          out.print ",#{set[:data][key][i]}"
        end
        out.puts
      end
    end
  end # out

  $stderr.puts

end # ARGV

unless $quiet
  $stderr.puts "Finished.  Press Enter to exit"
  $stdin.gets
end

