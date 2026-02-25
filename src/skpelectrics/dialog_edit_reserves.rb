require 'sketchup'
require_relative 'settings'

module Lvm444Dev
  module SkpElectricsDialogs
    module DialogsEditReserves

      def self.show_dialog
        length = SkpElectrics::Settings.get_cable_reserve_length

        prompts = ["На всех концах (мм):"]
        defaults = [length.to_s]
        input = UI.inputbox(prompts, defaults, 'Добавлять запас кабеля')
        return unless input

        length = input[0].to_i
        SkpElectrics::Settings.set_cable_reserve_length(length)
      end

    end
  end
end
