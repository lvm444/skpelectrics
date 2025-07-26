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
          model = Sketchup.active_model

          tags = Lvm444Dev::TagsDictionary.new(model)
          tags.load_from_model

          puts "tags #{tags}"

          puts "loaded - #{tags.to_json}"

          dialog.execute_script("onLoad('#{tags.to_json.to_json}')")
        end

        dialog
      end

      def self.show_dialog
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
        end

        @dialog = self.create_dialog
        @dialog.add_action_callback('saveTagsDictionary') { |action_context, tags|
          self.saveTagsDictionary(tags)
          nil
        }
        @dialog.add_action_callback('closeDialog') { |action_context|
          self.closeDialog
          nil
        }

        @dialog.show
      end

      def self.saveTagsDictionary(tags)
        model = Sketchup.active_model
        dict = Lvm444Dev::TagsDictionary.new(model)

        if (dict.load_from_string(tags))
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
