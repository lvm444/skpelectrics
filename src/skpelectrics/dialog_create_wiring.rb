module Lvm444Dev
  module SkpElectricsDialogs
    module DialogsCreateWiring
      def self.create_dialog
        html_file = File.join(__dir__, 'html', 'dialog_create_wiring.html') # Use external HTML
        options = {
          :dialog_title => "Material",
          :preferences_key => "Lvm444Dev.SkpElectricsDialogs.DialogsCreateWiring",
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

          wiring_type = Lvm444Dev::SkpElectricsWireType.get_selected_type


          dialog.execute_script("onload('#{wiring_type}','#{types.keys().to_json}',#{selectionType.to_json})")
        end

        dialog
      end

      def self.show_dialog
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
        end

        @dialog = self.create_dialog
        @dialog.add_action_callback('apply_edges_wiring_type') { |action_context, wiring_type|
          self.edit_wiring_type(wiring_type)
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
