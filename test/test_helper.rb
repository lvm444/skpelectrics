# Test helper for SkpElectrics project

# Mock SketchUp modules to allow loading files that depend on SketchUp
module Sketchup; end
module UI; end
module Geom; end
module Length; end

# Mock file_loaded? method for SketchUp extensions
module Kernel
  def file_loaded?(file)
    true
  end
end

# Mock SketchUp require to allow loading files that depend on SketchUp
module Kernel
  alias_method :original_require, :require

  def require(name)
    if name == 'sketchup.rb' || name == 'extensions.rb' || name == 'sketchup' || name == 'extensions'
      # Return true to indicate the modules are already loaded
      true
    else
      original_require(name)
    end
  end
end

# Load coverage if COVERAGE environment variable is set
if ENV['COVERAGE']
  require_relative 'coverage_helper'
end

# Always require minitest/autorun after coverage setup
require 'minitest/autorun'
require 'json'

# Configure Minitest reporters if available
begin
  require 'minitest/reporters'
  Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new
rescue LoadError
  puts "minitest-reporters not available, using default reporter"
end

# Mock SketchUp classes for testing
module TestMocks
  class MockModel
    def initialize
      @attribute_dictionaries = {}
    end

    def attribute_dictionary(name, create_if_missing = false)
      if create_if_missing && !@attribute_dictionaries[name]
        @attribute_dictionaries[name] = MockAttributeDictionary.new(name)
      end
      @attribute_dictionaries[name]
    end
  end

  class MockAttributeDictionary
    attr_reader :name, :attributes

    def initialize(name)
      @name = name
      @attributes = {}
    end

    def [](key)
      @attributes[key]
    end

    def []=(key, value)
      @attributes[key] = value
    end
  end

  class MockUI
    def self.messagebox(message)
      puts "UI Message: #{message}"
    end
  end

  class MockGroup
    attr_accessor :name, :entities, :attributes

    def initialize(name = "Test Group")
      @name = name
      @entities = []
      @attributes = {}
    end

    def add_entity(entity)
      @entities << entity
    end

    def get_attribute(dict_name, key, default = nil)
      dict = @attributes[dict_name] || {}
      dict[key] || default
    end

    def set_attribute(dict_name, key, value)
      @attributes[dict_name] ||= {}
      @attributes[dict_name][key] = value
    end
  end

  # Helper methods for test data
  def self.create_mock_model
    MockModel.new
  end

  def self.create_test_materials_data
    {
      "РОЗ" => {
        "cable" => "ВВГ нг 3x2.5",
        "conduit" => "Гофра 20мм"
      },
      "ОСВ" => {
        "cable" => "ВВГ нг 3x1.5",
        "conduit" => "Гофра 16мм"
      }
    }
  end
end
