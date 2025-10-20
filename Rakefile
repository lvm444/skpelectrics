require 'rake'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/unit/*_test.rb']
  t.verbose = true
end

desc 'Run all tests'
task default: :test

desc 'Run tests with coverage'
task :coverage do
  require 'simplecov'
  SimpleCov.start do
    add_filter '/test/'
    add_filter '/vendor/'
  end
  Rake::Task['test'].execute
end
