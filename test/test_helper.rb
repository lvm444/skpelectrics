# Test helper for SkpElectrics project
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
