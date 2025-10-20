require_relative '../test_helper'
require_relative '../../src/skpelectrics/material_dictionaries'

module Lvm444Dev
  class MaterialDictionariesTest < Minitest::Test
  def setup
    @mock_model = TestMocks.create_mock_model
    @test_data = TestMocks.create_test_materials_data
  end

  def test_initialization_with_empty_model
    # Test that dictionary initializes correctly with empty model
    dictionary = Lvm444Dev::ElectricalMaterialsDictionary.new(@mock_model)

    assert_instance_of Lvm444Dev::ElectricalMaterialsDictionary, dictionary
    assert_equal({}, dictionary.materials_data)
  end

  def test_add_line_type
    dictionary = Lvm444Dev::ElectricalMaterialsDictionary.new(@mock_model)

    # Test adding a new line type
    result = dictionary.add_line_type("РОЗ", @test_data["РОЗ"])

    assert result
    assert_equal @test_data["РОЗ"], dictionary.materials_data["РОЗ"]
  end

  def test_get_materials_by_type
    dictionary = Lvm444Dev::ElectricalMaterialsDictionary.new(@mock_model)
    dictionary.add_line_type("РОЗ", @test_data["РОЗ"])

    # Test getting existing materials
    materials = dictionary.get_materials_by_type("РОЗ")
    assert_equal @test_data["РОЗ"], materials

    # Test getting non-existing materials
    non_existing = dictionary.get_materials_by_type("NON_EXISTING")
    assert_nil non_existing
  end

  def test_load_from_string_valid_json
    dictionary = Lvm444Dev::ElectricalMaterialsDictionary.new(@mock_model)

    valid_json = @test_data.to_json
    result = dictionary.load_from_string(valid_json)

    assert result
    assert_equal @test_data, dictionary.materials_data
  end

  def test_load_from_string_invalid_json
    dictionary = Lvm444Dev::ElectricalMaterialsDictionary.new(@mock_model)

    invalid_json = "invalid json string"
    result = dictionary.load_from_string(invalid_json)

    refute result
    assert_equal({}, dictionary.materials_data)
  end

  def test_load_from_string_invalid_structure
    dictionary = Lvm444Dev::ElectricalMaterialsDictionary.new(@mock_model)

    # Invalid structure - not a hash
    invalid_data = [1, 2, 3].to_json
    result = dictionary.load_from_string(invalid_data)

    refute result
    assert_equal({}, dictionary.materials_data)
  end

  def test_save_to_model
    dictionary = Lvm444Dev::ElectricalMaterialsDictionary.new(@mock_model)
    dictionary.add_line_type("РОЗ", @test_data["РОЗ"])

    result = dictionary.save_to_model

    assert result

    # Verify data was saved to model attributes
    dict = @mock_model.attribute_dictionary("Skp_Electrics_ElectricalMaterialsData")
    assert dict
    assert dict["materials_json"]
    assert dict["last_updated"]

    # Verify JSON can be parsed back
    saved_data = JSON.parse(dict["materials_json"])
    assert_equal @test_data["РОЗ"], saved_data["РОЗ"]
  end

  def test_save_to_model_with_empty_data
    dictionary = Lvm444Dev::ElectricalMaterialsDictionary.new(@mock_model)

    result = dictionary.save_to_model

    # Should not save when data is empty
    refute result
  end

  def test_to_json
    dictionary = Lvm444Dev::ElectricalMaterialsDictionary.new(@mock_model)
    dictionary.add_line_type("РОЗ", @test_data["РОЗ"])

    json_output = dictionary.to_json
    parsed_json = JSON.parse(json_output)

    assert_equal @test_data["РОЗ"], parsed_json["РОЗ"]
  end

  def test_valid_dictionary_structure
    dictionary = Lvm444Dev::ElectricalMaterialsDictionary.new(@mock_model)

    # Test valid structure
    valid_data = {
      "РОЗ" => {
        "cable" => "ВВГ нг 3x2.5",
        "conduit" => "Гофра 20мм"
      }
    }

    # Test invalid structures
    invalid_data1 = "not a hash"
    invalid_data2 = {
      "" => { "cable" => "ВВГ нг 3x2.5" } # Empty line type
    }
    invalid_data3 = {
      "РОЗ" => "not a hash" # Materials not a hash
    }
    invalid_data4 = {
      "РОЗ" => {
        "cable" => "" # Empty material value
      }
    }

    # Use reflection to test private method
    dictionary.send(:load_from_string, valid_data.to_json)
    assert_equal valid_data, dictionary.materials_data
  end

  def test_multiple_line_types
    dictionary = Lvm444Dev::ElectricalMaterialsDictionary.new(@mock_model)

    # Add multiple line types
    @test_data.each do |line_type, materials|
      dictionary.add_line_type(line_type, materials)
    end

    # Verify all types are present
    @test_data.each do |line_type, expected_materials|
      actual_materials = dictionary.get_materials_by_type(line_type)
      assert_equal expected_materials, actual_materials
    end
  end
end
end
