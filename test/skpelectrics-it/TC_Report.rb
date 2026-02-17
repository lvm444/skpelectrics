require "testup/testcase"

module Lvm444Dev

  class TC_Report < TestUp::TestCase
    def setup
      @data = Lvm444Dev::SkpElectricsDialogs::DialogsCreateLineReport.collect_report_data
    end

    def test_room_summary
      assert_in_delta(24.702, get_room_summary('Кухня'), delta = 0.0001)
    end

    def test_line_type_summary
      assert_in_delta(6.584, get_line_type_summary('ОСВ'), delta = 0.0001)
      # запас 6 * 0.3 = 1.8
      assert_in_delta(18.118, get_line_type_summary('РОЗ'), delta = 0.0001)
      # запас 6 * 0.3 = 1.8
      # запас 2 * 0.3 = 0.6
    end

    def test_material_summary
      assert_in_delta(6.584, get_material_summary('ВВГ 3*1.5'), delta = 0.0001)
      assert_in_delta(18.118, get_material_summary('ВВГ 3*2.5'), delta = 0.0001)
    end

    def test_wirings
      wirings = @data[:wirings].keys.sort
      assert_equal(["Гофра", "Штроба"], wirings)
    end

    def test_line_01
      line = get_line_by_number('01')
      assert_equal('01', line[:line_number])
      assert_equal('РОЗ', line[:type])
      assert_equal('Кухня', line[:room])
      assert_nil(line[:description])
      assert_in_delta(12.072, line[:length], delta = 0.0001)
      # запас 6 * 0.3 = 1.8

      assert_in_delta(5.582, line[:wire_type_sums]['Гофра'], delta = 0.0001)
      assert_in_delta(4.690, line[:wire_type_sums]['Штроба'], delta = 0.0001)
    end

    def test_line_02
      line = get_line_by_number('02')
      assert_equal('РОЗ', line[:type])
      assert_equal('Плита (no wirings)', line[:description])
      assert_in_delta(6.046, line[:length], delta = 0.0001)
      # запас 2 * 0.3 = 0.6

      assert_equal({}, line[:wire_type_sums])
    end

    def test_line_03
      line = get_line_by_number('03')
      assert_equal('ОСВ', line[:type])
      assert_nil(line[:description])
      assert_in_delta(6.584, line[:length], delta = 0.0001)
      # запас 6 * 0.3 = 1.8

      assert_in_delta(2.914, line[:wire_type_sums]['Гофра'], delta = 0.0001)
      assert_in_delta(1.870, line[:wire_type_sums]['Штроба'], delta = 0.0001)
    end

    private
    def get_room_summary(name)
      @data[:summary][:lines_room_summary][name]
    end

    def get_line_type_summary(type)
      @data[:summary][:lines_type_summary][type]
    end

    def get_material_summary(desc)
      @data[:summary][:materials_summary][desc]
    end

    def get_line_by_number(line_number)
      @data[:lines].find { |line| line[:line_number] == line_number }
    end
  end

end
