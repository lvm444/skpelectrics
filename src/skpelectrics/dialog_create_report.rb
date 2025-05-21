module Lvm444Dev
  module SkpElectricsDialogs
    module DialogsCreateLineReport
      def self.create_dialog
        html_file = File.join(__dir__, 'html', 'dialog_create_report.html') # Use external HTML
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

          lines = Lvm444Dev::SketchupUtils.search_electric_lines

          lines_sorted = lines.sort_by { |item| [item.room, item.type] }

          lines_summary = calculate_summary(lines)

          validate_line_number_collisions(lines_sorted)

          dialog.execute_script("populateReport('#{lines_sorted.to_json}',#{Lvm444Dev::SketchupUtils.get_wiring_types(lines).to_json},#{lines_summary.to_json})")
        end

        dialog
      end

      def self.calculate_summary(lines)

        lines_type_summary = Hash.new()
        lines_room_summary = Hash.new()

        lines.each do |line|
          lines_type_summary[line.type] =  lines_type_summary.fetch(line.type,0).to_f + line.length
          lines_room_summary[line.room] =  lines_type_summary.fetch(line.room,0).to_f + line.length
        end

        {
          :lines_type_summary => lines_type_summary,
          :lines_room_summary => lines_room_summary,
        }
      end

      def self.validate_line_number_collisions(lines)
        line_hash = Hash.new()
        lines.each do |line|

          collisionkey = "#{line.line_number}#{line.type}"
          if line_hash[collisionkey] == nil
              line_hash[collisionkey] = line
            else
              throw_line_collision_ex(line,line_hash[collisionkey])
          end
        end
      end

      def self.throw_line_collision_ex(col_line1,col_line2)
        UI.messagebox(" Колизия линия 1 #{col_line1.to_desc} линия 2 #{col_line2.to_desc}" )
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

    end
  end
end
