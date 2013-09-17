require 'rake/testtask'

TEST_FILES = FileList.new

ActualElements = 'lib/abaqus/actual_elements.rb'
SubElements = Dir['lib/abaqus/element/*.rb']

task :default => :element

Dir['lib/**/*.rb'].each do |rbfile|
  a = rbfile.split("/").flatten
  a[0] = "test"
  a[-1] = "test_" + a.last
  test_file = a.join("/")
  #puts "#{test_file} => #{rbfile}"
  file test_file => [rbfile, "./mktest.rb"] do
    sh "ruby lib/mktest.rb #{rbfile}"
  end
  TEST_FILES.add(test_file)
end

Rake::TestTask.new("test" => TEST_FILES){|t|
  t.pattern = 'test/**/test_*.rb'
}
task :element => ActualElements

file ActualElements => SubElements do |t|
  puts "Updating #{ActualElements}."
  open(ActualElements,'w') do |out|
    SubElements.each do |x|
      out.puts "require 'abaqus/element/#{File.basename(x,'.rb')}'"
      puts x
    end
  end
end

task :doc do
  sh "rdoc -x test -x setup.rb"
end


task :dat_extract do
  sh "ruby -I lib -r exerb/mkexy  dat_extract.rb"
  File.rename("dat_extract.exy","dat_extract.file")
  open("dat_extract.exy","ab") do |out|
    out.print open("dat_extract.inc","rb").read.gsub(/RUBY_VERSION/,`ruby -v`.chomp)
    open("dat_extract.file","rb") do |f|
      flag = false
      while line = f.gets
        flag = true if line =~ /^file:/
        out.puts line if flag
      end
    end
  end
  sh "exerb -c cui dat_extract.exy"
end
