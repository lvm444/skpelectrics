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

          selectionType = Lvm444Dev::SelectionManager.get_one_level_selection_type

          electric_line = nil
          case selectionType[:selection_type]
          when 6
            if selectionType[:selected_count] > 1
              UI.messagebox("Выберите одну линию для редактирования")
              @dialog.close
              return
            else
              selection = Lvm444Dev::SelectionManager.get_selection

              electric_line = Lvm444Dev::SketchupUtils::ElectricLineParser.parse_group selection.first
              if electric_line === nil
                UI.messagebox("Не удалось определить линию")
                @dialog.close
                return
              end
            end
          when 5
            selection = Lvm444Dev::SelectionManager.get_selection
          else
            UI.messagebox("Выберите линии для создания или редактирования")
            @dialog.close
            return
          end


          types = Lvm444Dev::SketchupUtils.search_wtypes

          rooms = Lvm444Dev::SkpElectricsLinesManager.get_rooms

          next_number = Lvm444Dev::SkpElectricsLinesManager.get_next_number

          model = Sketchup.active_model
          tags = Lvm444Dev::TagsDictionary.new(model)
          tags.load_from_model

          types = tags.tags_types

          createData = {
            lineNumber: next_number.to_s,
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
            end,
            existingLine: electric_line
          }

          dialog.execute_script("initForm('#{createData.to_json}')")
        end

        dialog
      end

      def self.show_dialog
        if @dialog && @dialog.visible?
          @dialog.bring_to_front
        end

        @dialog = self.create_dialog
        @dialog.add_action_callback('createElectricLine') { |action_context, electric_line_data|
          puts "callback createElectricLine"
          self.crate_electric_line_group(electric_line_data)
          nil
        }

        @dialog.add_action_callback('editElectricLine') { |action_context, electric_line_data|
        puts "callback editElectricLine"
          self.edit_electric_line_group(electric_line_data)
          nil
        }

        @dialog.show
      end

      # создание линии
      def self.crate_electric_line_group(electric_line_data)
        model = Sketchup.active_model
        model.start_operation('Create Line group', true)
        selection = Lvm444Dev::SelectionManager.get_one_level_selection_type
        if (selection[:selection_type] === 5  && selection[:selected_count] > 0)
          Lvm444Dev::SketchupUtils.create_group(electric_line_data["fullName"])
        else
          UI.messagebox("Линии выбраны не корректно: #{selection[:selection_type]} - #{selection[:selected_count]}")
        end

        @dialog.close
      rescue => e
        model.abort_operation
        UI.messagebox("Ошибка создания линии: #{e.message}")

        @dialog.close

      end

      # создание линии
      def self.edit_electric_line_group(electric_line_data)
        model = Sketchup.active_model
        model.start_operation('Create Line group', true)

        group = Lvm444Dev::SelectionManager.get_selected_group

        if (group != nil)
          group.name = electric_line_data["fullName"]
        else
          UI.messagebox("Группа выбрана не корректно ")
        end

        @dialog.close
      rescue => e
        model.abort_operation
        puts "Error creating eline: #{e.message}"
        UI.messagebox("Ошибка создания линии: #{e.message}")

        @dialog.close

      end

    end
  end
end
