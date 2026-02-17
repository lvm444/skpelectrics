require_relative '../test_helper'
require_relative '../../src/skpelectrics/electric_line_parser'

module Lvm444Dev
  class ElectricLineParserTest < Minitest::Test
    def setup
      @mock_model = TestMocks.create_mock_model
    end

    def test_parse_line_pattern_1
      test_settings = Object.new
      def test_settings.get_line_template
        puts "используется МОК"
        '1'
      end

      Lvm444Dev::SketchupUtils::ElectricLineParser.injected_settings = test_settings

      group = TestMocks::MockGroup.new("1-РОЗ-101 Тестовая линия")
      puts "group !!!! #{group}"
      electric_line = Lvm444Dev::SketchupUtils::ElectricLineParser.parse_group group

      puts "lectric_line #{electric_line.inspect}"

      # 7. Assertions (проверки)
      assert electric_line, "Должен вернуть ElectricLineModel объект"
      assert_instance_of Lvm444Dev::ElectricLineModel, electric_line

      # Проверяем поля
      assert_equal "1", electric_line.line_number, "Номер линии должен быть '1'"
      assert_equal "РОЗ", electric_line.type, "Тип должен быть 'РОЗ'"
      assert_equal "101", electric_line.room, "Комната должна быть '101'"
      assert_equal "Тестовая линия", electric_line.description, "Описание должно совпадать"

      # Проверяем группу
      assert_equal group, electric_line.get_group, "Группа должна совпадать"
      assert_equal "1-РОЗ-101 Тестовая линия", electric_line.to_desc, "Описание группы должно совпадать"

    end

    def test_parse_line_pattern_2
      test_settings = Object.new
      def test_settings.get_line_template
        puts "используется МОК get_line_template = 2"
        '2'
      end

      Lvm444Dev::SketchupUtils::ElectricLineParser.injected_settings = test_settings

      group = TestMocks::MockGroup.new("3РОЗ1 ВВГНГ 3x1.5")
      puts "group !!!! #{group}"
      electric_line = Lvm444Dev::SketchupUtils::ElectricLineParser.parse_group group

      # 6. Assertions (проверки)
      assert electric_line, "Должен вернуть ElectricLineModel объект для pattern 2"
      assert_instance_of Lvm444Dev::ElectricLineModel, electric_line

      # Проверяем поля согласно pattern 2: "1РОЗ101 Тестовая линия pattern 2"
      assert_equal "3", electric_line.line_number, "Номер линии должен быть '3'"
      assert_equal "РОЗ", electric_line.type, "Тип должен быть 'РОЗ'"
      assert_equal "1", electric_line.room, "Комната должна быть '1'"
      assert_equal " ВВГНГ 3x1.5", electric_line.description,
                  "Описание должно быть ' ВВГНГ 3x1.5' (с пробелом в начале)"
    end

    def test_parse_line_pattern_3
      # 1. Создаем mock settings для pattern 3
      test_settings = Object.new
      def test_settings.get_line_template
        puts "используется МОК для pattern 3"
        '3'
      end

      # 2. Инжектируем mock
      Lvm444Dev::SketchupUtils::ElectricLineParser.injected_settings = test_settings

      # 3. Создаем тестовую группу с pattern 3
      group_name = "5РОЗ1 -- 3х2.5"
      group = TestMocks::MockGroup.new(group_name)
      puts "Тестовая группа (pattern 3): #{group.inspect}"

      # 4. Парсим группу
      electric_line = Lvm444Dev::SketchupUtils::ElectricLineParser.parse_group(group)

      # 6. Assertions (проверки)
      assert electric_line, "Должен вернуть ElectricLineModel объект для pattern 3"
      assert_instance_of Lvm444Dev::ElectricLineModel, electric_line

      # Проверяем поля согласно pattern 3: "101РОЗ01 -- Тестовая линия pattern 3"
      # line_number = room + "." + group_in_room = "101" + "." + "01" = "101.01"
      assert_equal "5.01", electric_line.line_number, "Номер линии должен быть '1'"
      assert_equal "РОЗ", electric_line.type, "Тип должен быть 'РОЗ'"
      assert_equal "5", electric_line.room, "Комната должна быть '5'"
      assert_equal "3х2.5", electric_line.description,
                  "Описание должно быть '3х2.5'"

      # Проверяем группу
      assert_equal group, electric_line.get_group, "Группа должна совпадать"
      assert_equal group_name, electric_line.to_desc, "Описание группы должно совпадать"

      puts "Тест pattern 3 успешно пройден!"
    end
  end
end
