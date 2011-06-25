
Dir.chdir( File::dirname(__FILE__))

list = ["abaqus.rb"]
list << Dir['abaqus/**/*.rb'].to_a


test_dir = "../test/"
test_abaqus_dir = "../test/abaqus/"


def mkdir_p(dir)
  parent = File::dirname(dir)
  p dir, parent
  unless File::directory?(parent)
    mkdir_p(parent)
  end
  Dir.mkdir(dir) unless File::directory?(dir)
end

p top_dir = File::expand_path("../")

list.flatten.each do |file|
  f = open(file)
  arr = []
  while line = f.gets
    if /if +\$0 *== *__FILE__/ === line
      break
    end
  end
  while line
    arr << line.sub(/^  /,'')
    line = f.gets
  end
  f.close
  unless arr.empty?
    arr.shift
    until arr.pop.strip.downcase == "end"
      true
    end
    dir = File.dirname(top_dir + '/test/' + file)
    unless File.directory?(dir)
      mkdir_p(dir)
    end
    out = open(dir + "/test_" + File::basename(file),"w")
    out.puts "#! /usr/bin/ruby"
    out.puts ""
    out.puts "$LOAD_PATH.unshift '#{top_dir}/lib'"
    out.puts "require '#{file}'"
    out.puts
    out.puts arr.join('')
  end
end



