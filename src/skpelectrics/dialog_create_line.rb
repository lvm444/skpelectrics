require 'json'

module Lvm444Dev
  module SkpElectricsDialogs
    module DialogsCreateLine
      def self.create_dialog
        html_file = File.join(__dir__, 'html', 'dialog_create_line.html') # Use external HTML
        options = {
          :dialog_title => "Create Line",
          :preferences_key => "Lvm444Dev.SkpElectricsDialogs.DialogsCreateLine",
          :style => UI::HtmlDialog::STYLE_DIALOG
        }
        dialog = UI::HtmlDialog.new(options)
        dialog.center
        dialog.set_file(html_file)

          # Add action callback to send data
        dialog.add_action_callback("dialog_ready") do |action_context|
          types = Lvm444Dev::SketchupUtils.search_wtypes

          selectionType = Lvm444Dev::SelectionManager.get_one_level_selection_type

          puts "selectionType!! #{selectionType.to_json}"

          rooms = Lvm444Dev::SkpElectricsLinesManager.get_rooms


          #dialog.execute_script("initForm('#{wiring_type}','#{types.keys().to_json}',#{selectionType.to_json})")
          puts "initForm #{rooms}"

          #createData = {
          #          lineNumber: "01",
          #          lineTypes: [
          #            { value: "РОЗЗ", name: "Розетки" },
          #            { value: "ОСВ", name: "Освещение" },
          #            { value: "РАБ", name: "Рабочий свет" },
          #            { value: "ДЕЖ", name: "Дежурный свет" },
          #            { value: "СЕТ", name: "Сеть" },
          #            { value: "ТЕЛ", name: "Телефония" }
          #          ],
          #          rooms: [
          #            { value: "ГОСТ", name: "Гостинная" },
          #            { value: "КУХ", name: "Кухня" },
          #            { value: "СПАЛ", name: "Спальня" },
          #            { value: "ВАН", name: "Ванная" },
          #            { value: "КОР", name: "Коридор" },
          #            { value: "ОФ", name: "Офис" }
          #          ]
          #        };

          model = Sketchup.active_model
          tags = Lvm444Dev::TagsDictionary.new(model)
          tags.load_from_model

          types = tags.tags_types

          createData = {
            lineNumber: "01",
            lineTypes: types.map do |type, data|
              {
                value: type,
                name: data["description"],
                groupPath: data["groupPath"],
                color: data["color"]
              }
            end,
            rooms: rooms.map do |room|
              {
                value: room
              }
            end
          }




          #puts "#{tags.tags_types}"

          tags.tags_types.each do |type,type_data|
            puts "type  #{type_data['description']} (#{type_data['color']})"
          end

          dialog.execute_script("initForm('#{createData.to_json}')")
        end

        dialog
      end

      def self.show_dialog
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
        end

        @dialog = self.create_dialog
        @dialog.add_action_callback('applySingleWiring') { |action_context, wiring_type|
          self.apply_edges_wiring_type(wiring_type)
          nil
        }

        @dialog.add_action_callback('applyGroupHVWiring') { |action_context, horizontalType, verticalType|
          self.applyGroupHVWiring(horizontalType, verticalType)
          nil
        }

        @dialog.add_action_callback('applyGroupWiringAll') { |action_context, wtype|
          self.applyGroupWiringAll(wtype)
          nil
        }

        @dialog.show
      end

      # редактирование линий в группе или тип прокладки у группы
      def self.apply_edges_wiring_type(wtype)

        selectionType = Lvm444Dev::SelectionManager.get_one_level_selection_type

        puts "selectionType #{selectionType.to_json}"

        if (selectionType[:selection_type] == Lvm444Dev::SelectionManager::SELECTED_EDGES)
          puts "selected edges"
          Lvm444Dev::SkpElectricsWireType.edit_wiring_type(wtype)
        end
        @dialog.close
      end

      # массовое редактирование электролиний с формирование типов прокладки из несгруппированных участков. Пример по осям - вертикальные = штроба / горизонтальные = гофра
      def self.applyGroupHVWiring(horizontalType, verticalType)

        selectionType = Lvm444Dev::SelectionManager.get_one_level_selection_type

        puts "selectionType #{selectionType.to_json}"

        if (selectionType[:selection_type] == Lvm444Dev::SelectionManager::SELECTED_ELECTRIC_LINES)
          lines = Lvm444Dev::SelectionManager.get_selected_electric_lines
          Lvm444Dev::SkpElectricsWireType.create_wire_types_vh_by_electric_lines(horizontalType,verticalType,lines)
        end

        @dialog.close
      end

      # массовое редактирование электролиний с формирование типов прокладки для всех несгруппированных
      def self.applyGroupWiringAll(wtype)

        selectionType = Lvm444Dev::SelectionManager.get_one_level_selection_type

        puts "selectionType #{selectionType.to_json}"

        if (selectionType[:selection_type] == Lvm444Dev::SelectionManager::SELECTED_ELECTRIC_LINES)
          lines = Lvm444Dev::SelectionManager.get_selected_electric_lines
          Lvm444Dev::SkpElectricsWireType.create_wire_types_by_electric_lines(wtype,lines)
        end
        @dialog.close
      end

    end
  end
end
