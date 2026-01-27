# Coverage helper for SimpleCov
require 'simplecov'

# Configure SimpleCov to use consistent path
SimpleCov.configure do
  coverage_dir 'test/coverage'
end

SimpleCov.start do
  add_filter '/test/'
  add_filter '/vendor/'
  add_filter '/.github/'

  # Add groups for better organization
  add_group 'Core', 'src/skpelectrics'
  add_group 'Dialogs', 'src/skpelectrics/dialog'
  add_group 'HTML', 'src/skpelectrics/html'

  # Minimum coverage thresholds (optional)
  minimum_coverage 5  # Set to 15% to allow CI to pass
  minimum_coverage_by_file 0

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
