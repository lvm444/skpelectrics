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
          puts "dialog ready!!!"
          #dialog.execute_script("print_report(#{items.to_json},#{totals[:lengths_by_type].to_a.to_json},#{totals[:lengths_by_rooms].to_a.to_json}),#{wiring_types.to_a.to_json}")

          types = Lvm444Dev::SketchupUtils.search_wtypes

          wiring_type = Lvm444Dev::SketchupUtils.get_selected_wiring_type()
          puts "seleted type #{wiring_type}"
          puts "types  #{types.keys().to_json}"
          dialog.execute_script("onload('#{wiring_type}','#{types.keys().to_json}')")
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
        Lvm444Dev::SketchupUtils.edit_wiring_type(wtype)
        @dialog.close
      end

    end
  end
end
