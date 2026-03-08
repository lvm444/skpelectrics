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

    def self.create_command(menutext, cmd)
      command = UI::Command.new(menutext, &cmd)
      yield(command) if block_given?
      command
    end

    unless file_loaded?(__FILE__)
      reload

      #inject dependencies
      if defined?(Lvm444Dev::SkpElectrics::Settings)
        Lvm444Dev::SketchupUtils::ElectricLineParser.injected_settings =
          Lvm444Dev::SkpElectrics::Settings
        puts "ElectricLineParser Settings - Injected"
      end

      commands = {}
      commands[:report] = create_command('Сформировать кабельный журнал',
        proc { Lvm444Dev::SkpElectricsDialogs::DialogsCreateLineReport.show_dialog }) { |command|
          command.tooltip = 'Кабельный журнал'
          command.status_bar_text = 'Сформировать кабельный журнал'
          command.large_icon = 'images/report.png'
          command.small_icon = 'images/report_small.png'
        }

      commands[:reserves] = create_command('Настройки запаса кабеля',
        proc { Lvm444Dev::SkpElectricsDialogs::DialogsEditReserves.show_dialog }) { |command|
          command.tooltip = 'Настройки запаса кабеля'
          command.status_bar_text = 'Добавлять запас кабеля в розетках, коробках, выключателях и т.д.'
          command.large_icon = 'images/reserves.png'
          command.small_icon = 'images/reserves_small.png'
        }

      toolbar = UI::Toolbar.new('Электрика SKP')
      toolbar.add_item(commands[:report])
      toolbar.add_item(commands[:reserves])
      toolbar.restore

      menu = UI.menu('Plugins').add_submenu('skpelectrics')

      menu.add_item('Настройки') {
        Lvm444Dev::SkpElectricsDialogs::DialogSetupSettings.show_dialog
      }

      menu.add_item('Создать линию') {
        Lvm444Dev::SkpElectricsDialogs::DialogsCreateLine.show_dialog
      }

      menu.add_item(commands[:report])

      menu.add_item('Указать способ прокладки кабеля') {
        Lvm444Dev::SkpElectricsDialogs::DialogsCreateWiring.show_dialog
      }

      menu.add_item('Отредактировать справочник материалов') {
        Lvm444Dev::SkpElectricsDialogs::DialogsEditMaterial.show_dialog
      }

      menu.add_item(commands[:reserves])

      line_transformations_menu = menu.add_submenu('Преобразования')

      line_transformations_menu.add_item('Выделить все эл. линии') {
        Lvm444Dev::SelectionManager.select_lines
      }

      line_transformations_menu.add_item('Разгруппировать группы типа прокладки') {
        Lvm444Dev::LineTransformationManager.ungroup_lines
      }

      # раскомментировать после доработки меток
      tags_menu = menu.add_submenu('Метки')

      tags_menu.add_item('Обновить метки') {
        Lvm444Dev::TagsManager.redefine_tags
      }

	    tags_menu.add_item('Настройки тэгов') {
        Lvm444Dev::SkpElectricsDialogs::DialogsEditTags.show_dialog
      }



      file_loaded(__FILE__)
    end

  end # module HelloCube
end # module Examples
