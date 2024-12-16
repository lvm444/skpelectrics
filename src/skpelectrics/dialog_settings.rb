module Lvm444Dev
  module SkpElectricsDialogs
    module DialogSetupSettings
      def self.create_dialog
        html_file = File.join(__dir__, 'html', 'dialog_settings.html') # Use external HTML
        options = {
          :dialog_title => "Material",
          :preferences_key => "Lvm444Dev.SkpElectricsDialogs.DialogsCreateReport",
          :style => UI::HtmlDialog::STYLE_DIALOG
        }
        dialog = UI::HtmlDialog.new(options)
        dialog.center
        dialog.set_file(html_file)

          # Add action callback to send data
        dialog.add_action_callback("dialog_ready") do |action_context|

          linepattern = Lvm444Dev::SkpElectrics::Settings.get_line_template

          puts "before unload #{linepattern}"
          dialog.execute_script("onload('#{linepattern}')")
        end

        dialog
      end

      def self.show_dialog
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
        end

        @dialog = self.create_dialog
        @dialog.add_action_callback('edit_template_setting') { |action_context, tempalte_num|
          self.edit_template_setting(tempalte_num)
          nil
        }
        @dialog.show
      end

      def self.edit_template_setting(template_num)
        Lvm444Dev::SkpElectrics::Settings.set_line_template(template_num)
      end

    end
  end
end
