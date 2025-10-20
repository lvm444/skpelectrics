#!/usr/bin/env ruby
# Simple test runner for SkpElectrics project

require_relative 'test_helper'

# Find and run all test files
test_files = Dir.glob('test/unit/*_test.rb')

puts "Running #{test_files.size} test files..."
puts "=" * 50

test_files.each do |test_file|
  puts "Running: #{File.basename(test_file)}"
  require_relative test_file
end

puts "=" * 50
puts "All tests completed successfully!"
