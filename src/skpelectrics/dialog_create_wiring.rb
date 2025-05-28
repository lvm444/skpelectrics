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

          wiring_type = Lvm444Dev::SkpElectricsWireType.get_selected_wiring_type()

          dialog.execute_script("onload('#{wiring_type}','#{types.keys().to_json}',#{selectionType.to_json})")
        end

        dialog
      end

      def self.show_dialog
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
        end

        @dialog = self.create_dialog
        @dialog.add_action_callback('edit_wiring_type') { |action_context, wiring_type|
          self.edit_wiring_type(wiring_type)
          nil
        }
        @dialog.show
      end

      def self.edit_wiring_type(wtype)

        selectionType = Lvm444Dev::SelectionManager.get_one_level_selection_type

        puts "selectionType #{selectionType.to_json}"

        if (selectionType[:selection_type] == Lvm444Dev::SelectionManager::SELECTED_EDGES)
          puts "selected edges"
          Lvm444Dev::SkpElectricsWireType.edit_wiring_type(wtype)
        elsif (selectionType[:selection_type] == Lvm444Dev::SelectionManager::SELECTED_MIX)
          puts "selected mix"
        elsif (selectionType[:selection_type] == Lvm444Dev::SelectionManager::SELECTED_ELECTRIC_LINES)
          lines = Lvm444Dev::SelectionManager.get_selected_electric_lines
          puts "selected electric lines!! #{lines}"
          Lvm444Dev::SkpElectricsWireType.create_wire_types_by_electric_lines(wtype,lines)
        end
        @dialog.close
      end

    end
  end
end
