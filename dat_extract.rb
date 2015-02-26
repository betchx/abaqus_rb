#! /usr/bin/ruby
# coding: Shift_JIS

begin

INC = /INCREMENT +(\d+) SUMMARY/ ;
FIN = /THE ANALYSIS HAS BEEN COMPLETED/;
FIN2 = /ANALYSIS COMPLETE/;
TERM = /PROBLEMS ENCOUNTERED/

# Require
require 'pp'
require 'optparse'
require 'abaqus'

# Ignore Unknown Element Type
Abaqus.enable_dummy

begin
$quiet = false
$pos_out = false
$transpose = false
$sor_tkey = nil
$dbg = false
$glmap = false
end

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
  t = 0.0

  # Create output directory
  Dir::mkdir(base) unless FileTest::directory?(base)

  # reset step counter
  $step = 0

  line = true

  # Main Loop Start
  while line
    # Skip to first increment
    until line =~ INC
      line = f.gets
      raise "No increment is found" if line.nil?

      # time inc
      if line =~ /FIXED TIME INCREMENTS/
        line = f.gets
        fixed_inc = line.strip.split.pop.to_f
      end
      # STEP
      if line =~ /S T E P +(\d)/
        $step = $1.to_i
        $stderr.puts "\n:Step #{$step}:"
      end
      # MAPS of Global-Local Node/Element IDS
      if line =~ /GLOBAL TO LOCAL NODE AND ELEMENT MAPS/
        $glmap = true
        $gn2ln = []
        $ge2le = []
        $ln2gn = {}
        $le2ge = {}
        4.times{f.gets}
        until (line = f.gets.strip).empty?
          gid, lid, inst = line.split
          $gn2ln[gid.to_i] = "#{inst}.#{lid}"
        end
        4.times{f.gets}
        until (line = f.gets.strip).empty?
          gid, lid, inst = line.split
          $ge2le[gid.to_i] = "#{inst}.#{lid}"
        end
        5.times{f.gets}
        until (line = f.gets.strip).empty?
          inst, lid, gid = line.split
          $ln2gn["#{inst}.#{lid}"] = gid
        end
        4.times{f.gets}
        until (line = f.gets.strip).empty?
          inst, lid, gid = line.split
          $le2ge["#{inst}.#{lid}"] = gid
        end
      end
    end

    $dbg.puts "#{__FILE__}:#{__LINE__}:I@#{f.lineno}:#{line}"  if $dbg

    # increment
    inc = line.scan(INC).flatten[0].to_i
    3.times{ line = f.gets }
    if fixed_inc
      t = fixed_inc * inc
    else
      dt = line.strip.split[3].to_f
      t += dt #line.split.pop.to_f
    end
    line =f.gets
    $stderr.print sprintf("\rinc %5d  time: %g", inc, t)

    # Element

    line = f.skip
    # check
    unless line =~ /E L E M E N T   O U T P U T/ ;
      raise "Element Output does not found in #{file} at #{f.lineno} "
    end

    while (line = f.skip)
      # termination Check
      break if line =~/N O D E   O U T P U T/;
      break if line =~ INC
      break if line =~ FIN
      break if line =~ FIN2
      break if line =~ /^1\r?\n?/  # Start of step

      # Check
      #$stderr.puts "line : '#{line}'"
      raise "#{line} @ #{f.lineno}" unless line =~ /THE FOLLOWING TABLE IS PRINTED AT THE/;

      # Obtain ELSET NAME
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

      # Point of Result (Center/Integration Point/Nodes)
      point = nil
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

      # Obtain Info
      info,head = f.skip.split(/-/,2)
      sz = info.size
      heads = head.strip.split.map{|x| x.strip}
      with_sec = info =~ /SEC/

      # Prepair Output Array
      outs[name] = [] if outs[name].nil?
      out = outs[name][$step]
      if out.nil?
        out = {:name=>name, :step => $step, :time => [], :heads => {}, :data => {}, :ids => {}, :keys => []}
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
                out[:keys] << key
                out[:data][key] ||= ["0"] * (inc - 1)
                out[:heads][key] = "#{h}@e#{eid}-pt#{pt}" + (sec ? "-sp#{sec}" : "")
                out[:ids][key] = eid
                if savepos
                  pos[:data][key] = model.element_center_pos(eid,partname)
                end
                if $glmap
                  key2 = [h, $le2ge[eid], pt, sec]
                  [:data, :heads, :ids].each{|x| out[x][key2] = out[x][key]}
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
                if $glmap
                  key2 = [h, $le2ge[eid], pt, sec]
                  [:data, :heads, :ids].each{|x| out[x][key2] = out[x][key]}
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
                if $glmap
                  key2 = [h, $le2ge[eid], sec]
                  [:data, :heads, :ids].each{|x| out[x][key2] = out[x][key]}
                end
              end
              out[:data][key] << val[i]
            end
          end until (line = f.gets).strip.empty?
          5.times{f.gets}
        end
      end
    end

    #termination check
    next if line =~ INC
    break if line =~ FIN
    break if line =~ FIN2
    break if line =~ TERM

    # Node
    unless line =~ /N O D E/
      $stderr.puts line
    end
    line = f.skip

    begin
      break if line =~ INC
      break if line =~ FIN
      break if line =~ FIN2
      break if line =~ TERM
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
      if outs[name].nil?
        outs[name] = []
      end
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
          as,ins,gn = name.split(/_/)
          nodes[name] = model.instances[ins].part.nsets[gn].sort
        elsif name =~ /ASSEMBLY_\w+/
          # need split
          as,gn = name.split(/_/)
          nodes[name] = model.nsets[gn].sort
        else
          raise "Node set '#{name}' does not found  ( #{file} line #{f.lineno} )"
        end
        $dbg.puts "#{__FILE__}:#{__LINE__}:N@#{f.lineno}:nodes: #{nodes[name].inspect}"  if $dbg
        out = {:name=>name, :step => $step, :time => [t], :heads => {}, :data => {}, :ids => {}, :keys => []}
        nodes[name].each do |nid|
          heads.each do |h|
            key = [h,nid.to_s]
            $dbg.puts "#{__FILE__}:#{__LINE__}:K@#{f.lineno}:key : #{key.inspect}"  if $dbg
            out[:keys] << key
            out[:heads][key] = "#{h}@#{nid}"
            out[:data][key] = []
            out[:ids][key] = nid
            if $glmap
              key2 = [h, $ln2gn[nid]]
              $dbg.puts "#{__FILE__}:#{__LINE__}:K@#{f.lineno}:key2: #{key2.inspect}"  if $dbg
              [:heads, :data, :ids].each{|x| out[x][key2] = out[x][key] }
            end
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
      2.times{
       line = f.gets
       }
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
    break if line =~ TERM


  end
  # Main Loop End

  f.close

  #outs.each do |k,out|
  #  out.close
  #end
  $stderr.puts
  outs.each do |name,sets|
    set = sets.last
    $dbg.puts "#{__FILE__}:#{__LINE__}:---:set : #{set.inspect}"  if $dbg
    keys = set[:keys]
    $dbg.puts "#{__FILE__}:#{__LINE__}:---:Keys: #{keys.inspect}"  if $dbg
    if $sort_key
      keys = set[:keys].sort_by{|key| $sort_key.downcase.split(//).map{|k|
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

rescue Exception => e
  #  trap all exception due to show the error message for users
  $stderr.puts
  $stderr.puts
  $stderr.puts "****ERROR****"
  $stderr.puts e.message
  $stderr.puts e.backtrace
  $stderr.puts "*************"
  $stderr.puts
 unless $quiet
  $stderr.puts "Press Enter to close"
  $stdin.gets
 end
end

