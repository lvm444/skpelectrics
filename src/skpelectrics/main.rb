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

    def self.create_commands()
      commands = {}

      commands[:report] = create_command('Сформировать кабельный журнал',
        proc { Lvm444Dev::SkpElectricsDialogs::DialogsCreateLineReport.show_dialog }) { |command|
          command.tooltip = 'Кабельный журнал'
          command.status_bar_text = 'Сформировать кабельный журнал'
          command.large_icon = 'images/report.png'
          command.small_icon = 'images/report_small.png'
        }

      commands[:create_line] = create_command('Создать линию',
        proc { Lvm444Dev::SkpElectricsDialogs::DialogsCreateLine.show_dialog }) { |command|
          command.tooltip = 'Формирование новой линии'
          command.status_bar_text = 'Сформировать новую электро линию из выделенного'
          command.large_icon = 'images/new_line.png'
          command.small_icon = 'images/new_line_small.png'
        }

      commands[:lineupdown_tool] = create_command('Нарисовать линию до потолка/пола',
        proc { Lvm444Dev::LineupdownTool.activate }) { |command|
          command.tooltip = 'Линия до потолка/пола'
          command.status_bar_text = 'Нарисовать линию от розетки (выключателя) до потолка/пола'
          command.large_icon = 'images/lineupdown.png'
          command.small_icon = 'images/lineupdown_small.png'
        }

      commands[:wire_type_tool] = create_command('Указать способ прокладки линии',
        proc { Lvm444Dev::SkpElectricsDialogs::DialogsCreateWiring.show_dialog }) { |command|
          command.tooltip = 'Указать способ прокладки линии'
          command.status_bar_text = 'Указать способ прокладки линии'
          command.large_icon = 'images/wire_type.png'
          command.small_icon = 'images/wire_type_small.png'
        }

      commands[:settings] = create_command('Настройки',
          proc { Lvm444Dev::SkpElectricsDialogs::DialogSetupSettings.show_dialog })
      commands[:create_wiring] = create_command('Указать способ прокладки кабеля',
          proc { Lvm444Dev::SkpElectricsDialogs::DialogsCreateWiring.show_dialog })
      commands[:material_settings] = create_command('Отредактировать справочник материалов',
          proc { Lvm444Dev::SkpElectricsDialogs::DialogsEditMaterial.show_dialog })
      commands[:reserve_settings] = create_command('Настройки запаса кабеля',
          proc { Lvm444Dev::SkpElectricsDialogs::DialogsEditReserves.show_dialog })

      commands[:lines_select] = create_command('Выделить все эл. линии',
          proc { Lvm444Dev::SelectionManager.select_lines })
      commands[:lines_ungroup_wirings] = create_command('Разгруппировать группы типа прокладки',
          proc { Lvm444Dev::LineTransformationManager.ungroup_lines })

      commands[:tags_redefine] = create_command('Обновить метки',
          proc { Lvm444Dev::TagsManager.redefine_tags })
      commands[:tags_settings] = create_command('Настройки меток',
          proc { Lvm444Dev::SkpElectricsDialogs::DialogsEditTags.show_dialog })

      commands
    end

    unless file_loaded?(__FILE__)
      reload

      #inject dependencies
      if defined?(Lvm444Dev::SkpElectrics::Settings)
        Lvm444Dev::SketchupUtils::ElectricLineParser.injected_settings =
          Lvm444Dev::SkpElectrics::Settings
        puts "ElectricLineParser Settings - Injected"
      end

      commands = create_commands()

      toolbar = UI::Toolbar.new('Электрика SKP')
      toolbar.add_item(commands[:report])
      toolbar.add_item(commands[:create_line])
      toolbar.add_item(commands[:lineupdown_tool])
      toolbar.restore

      menu = UI.menu('Plugins').add_submenu('skpelectrics')

      menu.add_item(commands[:settings])
      menu.add_item(commands[:create_line])
      menu.add_item(commands[:lineupdown_tool])
      menu.add_item(commands[:report])
      menu.add_item(commands[:create_wiring])
      menu.add_item(commands[:material_settings])
      menu.add_item(commands[:reserve_settings])

      line_transformations_menu = menu.add_submenu('Преобразования')
      line_transformations_menu.add_item(commands[:lines_select])
      line_transformations_menu.add_item(commands[:lines_ungroup_wirings])

      tags_menu = menu.add_submenu('Метки')
      tags_menu.add_item(commands[:tags_redefine])
      tags_menu.add_item(commands[:tags_settings])

      file_loaded(__FILE__)
    end

  end # module HelloCube
end # module Examples
