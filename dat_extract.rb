#! /usr/bin/ruby
# coding: Shift_JIS

INC = /INCREMENT +(\d+) SUMMARY/ ;
FIN = /THE ANALYSIS HAS BEEN COMPLETED/;
FIN2 = /ANALYSIS COMPLETE/;

require 'pp'
require 'optparse'
require 'abaqus'

$quiet = false
$pos_out = false
$transpose = false
$sor_tkey = nil
$dbg = false

OptionParser.new do |opt|
  opt.on('-q', '--quiet', "Skip Conformation"){
    $quiet = true
  }
  opt.on('-p', '--pos', "Add position(Coordinate) of node/element will be written as step 0"){
    $pos_out = true
  }
  opt.on('-t', '--transpose', "Output results with transpose (Usefull for stress distribution)"){
    $transpose = true
  }
  opt.on('-k key', "--key=key","order will be sorted by the key. key will be x,y,z or i. i is id number. -p option is require for key =x,y or z."){ |k|
    $sort_key = k
  }
  opt.on('-D', "--bebug", "Output log massege into debug.log"){
    $dbg = open("debug_out.log", "w")
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
    return wk
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

    $dbg.puts "#{__FILE__}:#{__LINE__}:I@#{f.lineno}:#{line}"  if $dbg

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
      if elname =~  /ASSEMBLY_(\w+)_(\w+)/ then
        partname = $1
        setname = $2
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
      info,head = f.skip.split(/-/,2)
      sz = info.size
      heads = head.strip.split.map{|x| x.strip}
      with_sec = info =~ /SEC/
      outs[name] = [] if outs[name].nil?
      out = outs[name][$step]
      if out.nil?
        out = {:name=>name, :step => $step, :time => [], :heads => {}, :data => {}, :ids => {}}
        outs[name][$step] = out
      end
      1.times{f.gets}
      out[:time][inc-1] = t
      line = f.skip
      savepos = ($step == 1 && $pos_out)
      if savepos
        pos = {:name=>name, :step => "pos", :time => %w(x y z), :heads => out[:heads], :data => {}, :ids =>out[:ids]}
        outs[name][0] = pos
      end
      case point
      when :integ
        unless line =~ /ALL VALUES/
          begin
            if with_sec
              eid, pt, sec, *val = line[0..sz].strip.split
            else
              sec = nil
              eid, pt, *val = line.strip.split
            end
            val = line[sz..-1].strip.split
            unless val.size == heads.size
              raise "number of headers and vals does not match \nheads:#{heads.inspect}\nval:#{val.inspect}\nline:#{line.inspect}" 
            end
            heads.each_with_index do |h,i|
              key = [h,eid,pt,sec]
              if out[:data][key].nil?
                out[:data][key] ||= ["0"] * (inc - 1)
                out[:heads][key] = "#{h}@e#{eid}-pt#{pt}" + (sec ? "-sp#{sec}" : "")
                out[:ids][key] = eid
                if savepos
                  pos[:data][key] = model.element_center_pos(eid,partname)
                end
              end
              out[:data][key] << val[i]
            end
          end until (line = f.gets).strip.empty?
          5.times{f.gets}
        end
      when :elnode
        unless line =~ /ALL VALUES/
          begin
            if with_sec
              eid, pt, sec, *val = line.strip.split
            else
              sec = nil
              eid, pt, *val = line.strip.split
            end
            val = line[sz..-1].strip.split
            raise "number of headers and vals does not match \n#{heads}\n#{val}\n" unless val.size == heads.size
            heads.each_with_index do |h,i|
              key = [h,eid,pt,sec]
              if out[:data][key].nil?
                out[:data][key] ||= ["0"] * (inc - 1)
                out[:heads][key] = "#{h}@e#{eid}-n#{pt}" + (sec ? "-sp#{sec}" : "")
                out[:ids][key] = eid
                if savepos
                  pos[:data][key] = model.element_center_pos(eid,partname)
                end
              end
              out[:data][key] << val[i]
            end
          end until (line = f.gets).strip.empty?
          5.times{f.gets}
        end
      when :center
        unless line =~ /ALL VALUES/
          begin
            if with_sec
              eid, sec, *val = line.split
            else
              sec = nil
              eid, *val = line.split
            end
            val = line[sz..-1].strip.split
            raise "number of headers and vals does not match \n#{heads}\n#{val}\n" unless val.size == heads.size
            heads.each_with_index do |h,i|
              key = [h,eid,sec]
              if out[:data][key].nil?
                out[:data][key] = ["0"] * (inc - 1)
                out[:heads][key] = "#{h}@e#{eid}" + (sec ? "-sp#{sec}" : "")
                out[:ids][key] = eid
                if savepos
                  pos[:data][key] = model.element_center_pos(eid,partname)
                end
              end
              out[:data][key] << val[i]
            end
          end until (line = f.gets).strip.empty?
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
        $dbg.puts "#{__FILE__}:#{__LINE__}:N@#{f.lineno}:name[#{name}]"  if $dbg
        wk = f.gets.strip
      end until wk.empty?
      raise if name =~ / /;
      break if name == "subsidiary."  # begining of step

      $dbg.puts "#{__FILE__}:#{__LINE__}:N@#{f.lineno}:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"  if $dbg
      line = f.skip
      heads = line.split(/-/,2).pop.split.map{|x| x.strip}

      outs[name] = [] if outs[name].nil?
      out = outs[name][$step]
      if out.nil?
        $dbg.puts "#{__FILE__}:#{__LINE__}:O@#{f.lineno}:Initialize outs[#{name}][#{$step}]"  if $dbg
        prt = nil
        if model.nsets[name]
          nodes[name] = model.nsets[name].sort
        elsif model.steps[$step-1].nsets[name]
          nodes[name] = model.steps[$step-1].nsets[name].sort
        elsif name =~ /ASSEMBLY_\w+_\w+/
          # need split
          as,prt,gn = name.split(/_/)
          nodes[name] = model.parts[prt].nsets[gn].sort
        else
          raise "Node set '#{name}' does not found  ( #{file} line #{f.lineno} )"
        end
        $dbg.puts "#{__FILE__}:#{__LINE__}:N@#{f.lineno}:nodes: #{nodes[name].inspect}"  if $dbg
        out = {:name=>name, :step => $step, :time => [t], :heads => {}, :data => {}, :ids => {}}
        nodes[name].each do |nid|
          heads.each do |h|
            key = [h,nid.to_s]
            $dbg.puts "#{__FILE__}:#{__LINE__}:K@#{f.lineno}:key : #{key.inspect}"  if $dbg
            out[:heads][key] = "#{h}@#{nid}"
            out[:data][key] = []
            out[:ids][key] = nid
          end
        end
        outs[name][$step] = out
        if $step == 1 && $pos_out
          # make result by coordinate of nodes
          pos = {:name=>name, :step => "pos", :time => %w(x y z), :heads => out[:heads], :data => {}, :ids => out[:ids]}
          $dbg.puts "#{__FILE__}:#{__LINE__}:P@#{f.lineno}:pos: #{pos.inspect}"  if $dbg
          nodes[name].each do |nid|
            heads.each do |h|
              key = [h,nid.to_s]
              if prt
                nd = model.parts[prt].nodes[nid]
              else
                nd = model.nodes[nid]
              end
              pos[:data][key] = [nd.x, nd.y, nd.z]
            end
          end
          outs[name][0] = pos
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
            $dbg.puts "#{__FILE__}:#{__LINE__}:N@#{f.lineno}:Key: #{key.inspect}"  if $dbg
            if out[:data][key].nil?
              $dbg.puts "#{__FILE__}:#{__LINE__}:X@#{f.lineno}:name: #{name.inspect}"  if $dbg
              $dbg.puts "#{__FILE__}:#{__LINE__}:X@#{f.lineno}:out[:name]: #{out[:name].inspect}"  if $dbg
              $dbg.puts "#{__FILE__}:#{__LINE__}:X@#{f.lineno}:out[:data]: #{out[:data].inspect}"  if $dbg
              $dbg.puts "#{__FILE__}:#{__LINE__}:X@#{f.lineno}:key: #{key.inspect}"  if $dbg
              out[:data][key] = []
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
  $stderr.puts
  outs.each do |name,sets|
    set = sets.last
    $dbg.puts "#{__FILE__}:#{__LINE__}:---:set : #{set.inspect}"  if $dbg
    keys = set[:data].keys
    $dbg.puts "#{__FILE__}:#{__LINE__}:---:Keys: #{keys.inspect}"  if $dbg
    if $sort_key
      keys = set[:data].keys.sort_by{|key| $sort_key.downcase.split(//).map{|k|
        case k
        when "i"
          set[:ids][key]
        when "x","y","z"
          if sets[0].nil?
            $stderr.puts "Warning:key #{k} is ignored due to missing -p option"
            ""
          else
            sets[0][:data][key]["xyz".index(k)]
          end
        when "h","t"
          key[0]
        else
          $stderr.puts "Warning: Unknown key #{k} is ignored"
          ""
        end
      }} # sort_by!
    else
      keys = set[:data].keys
    end

    open("#{base}/#{name}.csv","w") do |out|
     if $transpose
      out.print "step"
      0.upto($step) do |step|
        set = sets[step] or next
        set[:time].each{out.print ",#{step}"}
      end
      out.puts

      out.print "time"
      0.upto($step) do |step|
        set = sets[step] or next
        set[:time].each {|t| out.print ",#{t}" }
      end
      out.puts

      keys.each do |key|
        out.print "#{set[:heads][key]}"
        0.upto($step) do |step|
          set = sets[step] or next
          out.print "," + set[:data][key].join(",")
        end
        out.puts
      end
     else
      # not transpose
      out.print "step,time"
      keys.each do |key|
        out.print ",#{set[:heads][key]}"
      end
      out.puts
      0.upto($step) do |step|
        set = sets[step] or next
        data = set[:data]
        set[:time].each_with_index do |t,i|
          out.print [set[:step],t].join(",")
          keys.each do |key|
            p key if data[key].nil?
            out.print ",#{data[key][i]}"
          end
          out.puts
        end
      end
     end
    end

  end # out

  $stderr.puts

end # ARGV

unless $quiet
  $stderr.puts "Finished.  Press Enter to exit"
  $stdin.gets
end

