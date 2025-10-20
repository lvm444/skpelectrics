#!/usr/bin/env ruby
# Test runner that loads all source files for proper coverage tracking

# Load the test helper first to set up SketchUp mocks
require_relative 'test_helper'

# Eager load all source files BEFORE SimpleCov to ensure they're tracked
puts "Eager loading source files..."
source_files = Dir.glob('../src/**/*.rb')

source_files.each do |file|
  begin
    puts "Loading: #{file}"
    load file  # Use load instead of require to force reload
  rescue => e
    puts "Warning: Could not load #{file}: #{e.message}"
  end
end

# Start SimpleCov AFTER all source files are loaded
require 'simplecov'

SimpleCov.start do
  add_filter '/test/'
  add_filter '/vendor/'
  add_filter '/.github/'

  # Enable coverage tracking
  enable_coverage :line
  enable_coverage :branch

  # Track all source files
  track_files 'src/**/*.rb'

  # Add groups for better organization
  add_group 'Core', 'src/skpelectrics'
  add_group 'Dialogs', 'src/skpelectrics/dialog'
  add_group 'HTML', 'src/skpelectrics/html'

  # Minimum coverage thresholds (optional)
  minimum_coverage 15
  minimum_coverage_by_file 60

  # Output format
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])

  command_name 'All Tests'
end

puts "Coverage tracking enabled for all source files..."

# Now load minitest and run tests
require 'minitest/autorun'
require 'json'

# Configure Minitest reporters if available
begin
  require 'minitest/reporters'
  Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
rescue LoadError
  puts "minitest-reporters not available, using default reporter"
end

# Find and run all test files
test_files = Dir.glob('unit/*_test.rb')

puts "Running #{test_files.size} test files..."
puts "=" * 50

test_files.each do |test_file|
  puts "Running: #{test_file}"
  require_relative test_file
end

puts "=" * 50
puts "All tests completed!"
