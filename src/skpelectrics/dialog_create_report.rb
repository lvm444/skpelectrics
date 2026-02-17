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
        lines_data = collect_lines_data(lines)

        {
          lines: lines_data,
          summary: calculate_summary(lines_data),
          wirings: get_wiring_types(lines_data),
          warnings: validate_line_number_collisions(lines)
        }
      end

      def self.collect_lines_data(lines)
        lines
          .sort_by { |item| [item.room, item.type] }
          .map do |line|
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

        lines_type_summary = Hash.new(0.0)
        lines_room_summary = Hash.new(0.0)
        materials_summary = Hash.new(0.0)

        lines.each do |line|
          line_length = line[:length]
          line_type = line[:type]

          lines_type_summary[line_type] += line_length
          lines_room_summary[line[:room]] += line_length

          materials_hash = dict.get_materials_by_type(line_type)
          if (materials_hash != nil)
            materials_hash.each do |material_id,material_desc|
              materials_summary[material_desc] += line_length
            end
          else
            unknown_material = "Не определено - #{line_type}"
            materials_summary[unknown_material] += line_length
          end
        end

        {
          :lines_type_summary => lines_type_summary,
          :lines_room_summary => lines_room_summary,
          :materials_summary => materials_summary
        }
      end

      def self.get_wiring_types(lines)
        wtypes = Hash.new(0.0)
        lines.each do |line|
          line[:wire_type_sums].each do |wtype, len|
            wtypes[wtype] += len
          end
        end
        wtypes
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
