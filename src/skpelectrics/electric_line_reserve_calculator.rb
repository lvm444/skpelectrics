require_relative 'dialog_settings'

module Lvm444Dev
  module ElectricLine

    class ReserveCalculator
      def initialize
        @reserve_mm = Lvm444Dev::SkpElectrics::Settings.get_cable_reserve_length
      end

      # @param line [Lvm444Dev::ElectricLineModel] электрическая линия
      def length_with_reserve(line)
        return line.length if @reserve_mm.nil?

        reserve_length = line.cable_ends_count * @reserve_mm / 1000.0
        line.length + reserve_length
      end
    end

  end
end
