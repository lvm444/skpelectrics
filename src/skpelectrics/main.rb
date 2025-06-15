# Copyright 2016-2022 Trimble Inc
# Licensed under the MIT license

require 'sketchup.rb'

module Lvm444Dev
  module Main

    def self.reload
      Dir.glob(File.join(__dir__, '*.rb')).each do |file|
       next if File.basename(file) == "main.rb"
       load file
      end
    end

    unless file_loaded?(__FILE__)
      reload
      menu = UI.menu('Plugins').add_submenu('skpelectrics')

      menu.add_item('Настройки') {
        Lvm444Dev::SkpElectricsDialogs::DialogSetupSettings.show_dialog
      }

      menu.add_item('Сформировать кабельный журнал') {
        Lvm444Dev::SkpElectricsDialogs::DialogsCreateLineReport.show_dialog
      }

      menu.add_item('Указать способ прокладки кабеля') {
        Lvm444Dev::SkpElectricsDialogs::DialogsCreateWiring.show_dialog
      }

      menu.add_item('Отредактировать справочник материалов') {
        Lvm444Dev::SkpElectricsDialogs::DialogsEditMaterial.show_dialog
      }

      menu.add_item('Обновить метки') {
        Lvm444Dev::TagsManager.redefine_tags
      }

      menu.add_item('Выделить все эл. линии') {
        Lvm444Dev::SelectionManager.select_lines
      }

      file_loaded(__FILE__)
    end
  end # module HelloCube
end # module Examples
