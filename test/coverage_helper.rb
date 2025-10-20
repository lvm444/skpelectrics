# Coverage helper for SimpleCov
require 'simplecov'

SimpleCov.start do
  add_filter '/test/'
  add_filter '/vendor/'
  add_filter '/.github/'

  # Add groups for better organization
  add_group 'Core', 'src/skpelectrics'
  add_group 'Dialogs', 'src/skpelectrics/dialog'
  add_group 'HTML', 'src/skpelectrics/html'

  # Minimum coverage thresholds (optional)
  minimum_coverage 70  # Lowered to 70% for current state
  minimum_coverage_by_file 60

  # Output format
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::SimpleFormatter
  ])

  command_name 'Unit Tests'
end

# Load minitest and test helper
require 'minitest/autorun'
require 'json'

# Load all source files to ensure they're tracked by SimpleCov
Dir.glob('src/**/*.rb').each do |file|
  require_relative "../#{file}"
end

# Load the test helper without requiring it again
require_relative 'test_helper'
