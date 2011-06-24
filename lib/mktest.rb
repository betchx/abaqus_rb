
list = ["abaqus.rb"]
list << Dir['abaqus/**/*.rb'].to_a

Dir.chdir( File::dirname(__FILE__))

test_dir = "../test/"
test_abaqus_dir = "../test/abaqus/"

Dir.mkdir(test_dir) unless File.diretory?(test_dir)
Dir.mkdir(test_abaqus_dir) unless File.diretory?(test_abaqus_dir)

list.flatten.each do |file|
  out = open(test_dir + file,"w")
  out.puts "#! /usr/bin/ruby"
  out.puts ""
  out.puts "require '../lib/#{file}'"
  out.puts
  f = open(file)
  arr = []
  while line = f.gets
    if /if +\$0 *== *__FILE__/ === line
      break
    end
  end
  while line
    arr << line
    line = f.gets
  end
  f.close
  until arr.pop.strip.downcase == "end"
    true
  end
  out.puts arr.join('')
end



