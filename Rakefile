require 'rake/testtask'

TEST_FILES = FileList.new

Dir['lib/**/*.rb'].each do |rbfile|
  a = rbfile.split("/").flatten
  a[0] = "test"
  a[-1] = "test_" + a.last
  test_file = a.join("/")
  puts "#{test_file} => #{rbfile}"
  file test_file => rbfile do
    sh "ruby lib/mktest.rb #{rbfile}"
  end
  TEST_FILES.add(test_file)
end

Rake::TestTask.new("test" => TEST_FILES){|t|
  t.pattern = 'test/**/test_*.rb'
}

task :default => :test
