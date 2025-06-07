module Lvm444Dev
  module SkpElectricsDialogs
    module DialogsEditTags
      def self.create_dialog
        html_file = File.join(__dir__, 'html', 'dialog_edit_tags.html') # Use external HTML
        options = {
          :dialog_title => "Material",
          :preferences_key => "Lvm444Dev.SkpElectricsDialogs.DialogsEditTags",
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

          wiring_type = Lvm444Dev::SketchupUtils.get_selected_wiring_types()
          puts "seleted type #{wiring_type}"
          puts "types  #{types.keys().to_json}"

          model = Sketchup.active_model
          dict = Lvm444Dev::ElectricalMaterialsDictionary.new(model)

          puts "loaded - #{dict.to_json}"

          dialog.execute_script("onLoad('#{dict.to_json}')")
        end

        dialog
      end

      def self.show_dialog
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
        end

        @dialog = self.create_dialog
        @dialog.add_action_callback('saveMaterialsDictionary') { |action_context, materials|
          self.saveMaterialsDictionary(materials)
          nil
        }
        @dialog.add_action_callback('closeDialog') { |action_context|
          self.closeDialog
          nil
        }

        @dialog.show
      end

      def self.saveMaterialsDictionary(materials)
        model = Sketchup.active_model
        dict = Lvm444Dev::ElectricalMaterialsDictionary.new(model)

        if (dict.load_from_string(materials))
          puts "справочник успешно отредактирован!"
          if (dict.save_to_model)
            puts "справочник успешно сохранен!"
            @dialog.close
          end
        end
      end

      def self.closeDialog
        @dialog.close
      end

    end
  end
end
