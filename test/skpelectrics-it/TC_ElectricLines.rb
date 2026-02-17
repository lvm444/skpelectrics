require "testup/testcase"

module Lvm444Dev

  class TC_ElectricLines < TestUp::TestCase
    @lines = []

    def setup
      @lines = Lvm444Dev::SketchupUtils.search_electric_lines
    end

    def test_search
      assert_equal(3, @lines.size)
    end

    def test_attributes
      line = get_line('02-РОЗ-Кухня Плита (no wirings)')

      assert_equal('02', line.line_number)
      assert_equal('РОЗ', line.type)
      assert_equal('Кухня', line.room)
      assert_equal('Плита (no wirings)', line.description)
    end

    def test_line_info_01
      line = get_line_info('01-РОЗ-Кухня')

      assert_in_delta(5.582 + 4.690, line[:length], delta = 0.0001)
      assert_in_delta(5.582, line[:wirings]['Гофра'], delta = 0.0001)
      assert_in_delta(4.690, line[:wirings]['Штроба'], delta = 0.0001)
    end

    def test_line_info_02
      line = get_line_info('02-РОЗ-Кухня Плита (no wirings)')

      assert_in_delta(5.446, line[:length], delta = 0.0001)
      assert_equal({}, line[:wirings])
    end

    def test_line_info_03
      line = get_line_info('03-ОСВ-Кухня')

      assert_in_delta(2.914 + 1.870, line[:length], delta = 0.0001)
      assert_in_delta(2.914, line[:wirings]['Гофра'], delta = 0.0001)
      assert_in_delta(1.870, line[:wirings]['Штроба'], delta = 0.0001)
    end

    private
    def get_line_info(name)
      line = get_line(name)

      {
        :length => line.length,
        :wirings => line.wire_type_sums,
      }
    end

    # @return [Lvm444Dev::ElectricLineModel] электрическая линия
    def get_line(name)
      @lines.find(proc { flunk("Line not found: #{name}") }) do |line|
        line.to_desc == name
      end
    end
  end

end
