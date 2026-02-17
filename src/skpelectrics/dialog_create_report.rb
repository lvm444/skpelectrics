require 'sketchup'
require_relative 'settings'
require_relative 'dialog_settings'
require_relative 'sketchuputils'

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
          # check pattern settings
          pattern_number = Lvm444Dev::SkpElectrics::Settings.get_line_template

          if pattern_number == nil
            Lvm444Dev::SkpElectricsDialogs::DialogSetupSettings.show_dialog
            raise "parser error unknown line pattern number"
            return
          end

          data = collect_report_data()

          dialog.execute_script("populateReport('#{data[:lines].to_json}',#{data[:wirings].to_json},#{data[:summary].to_json},#{data[:warnings].to_json})")
        end

        dialog
      end

      def self.collect_report_data()
        lines = Lvm444Dev::SketchupUtils.search_electric_lines

        lines_sorted = lines.sort_by { |item| [item.room, item.type] }
        {
          lines: collect_lines_data(lines_sorted),
          summary: calculate_summary(lines),
          wirings: Lvm444Dev::SketchupUtils.get_wiring_types(lines),
          warnings: validate_line_number_collisions(lines)
        }
      end

      def self.collect_lines_data(lines)
        lines.map do |line|
          {
            line_number: line.line_number,
            type: line.type,
            room: line.room,
            description: line.description,
            length: line.length,
            wire_type_sums: line.wire_type_sums
          }
        end
      end

      def self.calculate_summary(lines)

        model = Sketchup.active_model
        dict = Lvm444Dev::ElectricalMaterialsDictionary.new(model)

        lines_type_summary = Hash.new()
        lines_room_summary = Hash.new()
        materials_summary = Hash.new()

        lines.each do |line|
          lines_type_summary[line.type] =  lines_type_summary.fetch(line.type,0).to_f + line.length
          lines_room_summary[line.room] =  lines_room_summary.fetch(line.room,0).to_f + line.length

          materials_hash = dict.get_materials_by_type(line.type)
          if (materials_hash != nil)
            materials_hash.each do |material_id,material_desc|
              materials_summary[material_desc] =  materials_summary.fetch(material_desc,0).to_f + line.length
            end
          else
            unknown_material = "Не определено - #{line.type}"
            materials_summary[unknown_material] =  materials_summary.fetch(unknown_material,0).to_f + line.length
          end
        end

        {
          :lines_type_summary => lines_type_summary,
          :lines_room_summary => lines_room_summary,
          :materials_summary => materials_summary
        }
      end

      def self.validate_line_number_collisions(lines)
        warnings = []

        line_hash = Hash.new()
        lines.each do |line|

          collisionkey = "#{line.line_number}#{line.type}"
          if line_hash[collisionkey] == nil
              line_hash[collisionkey] = line
            else
              warnings << format_line_collision_warning(line,line_hash[collisionkey])
          end
        end

        warnings
      end

      def self.format_line_collision_warning(col_line1,col_line2)
        "Колизия линия 1 #{col_line1.to_desc} линия 2 #{col_line2.to_desc}"
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
