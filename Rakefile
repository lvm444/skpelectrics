require 'rake'
require 'rake/testtask'

# Configure test task to load test_helper.rb first
Rake::TestTask.new do |t|
  t.libs << 'test'
  t.test_files = FileList['test/unit/*_test.rb']
  t.verbose = true
  # Ensure test_helper.rb is loaded first
  t.ruby_opts = ['-r', './test/test_helper.rb']
end

desc 'Run all tests'
task default: :test

desc 'Run tests with coverage'
task :coverage do
  ENV['COVERAGE'] = 'true'
  Rake::Task['test'].execute
end

desc 'Generate coverage report'
task :coverage_report do
  puts "Coverage report generated in coverage/index.html"
end
