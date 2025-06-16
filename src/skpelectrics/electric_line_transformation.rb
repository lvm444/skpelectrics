require 'sketchup.rb'
require 'extensions.rb'

module Lvm444Dev
  module LineTransformationManager
    def self.ungroup_lines
      lines = Lvm444Dev::SelectionManager.get_selected_electric_lines

      model = Sketchup.active_model
      model.start_operation('ungroup wire groups', true)

      lines.each do |line|
        puts "explode line #{line.to_desc}"
        LineTransformation.explode_wire_groups(line)
      end
      model.commit_operation
    rescue => e
      model.abort_operation
      puts "Error ungroup wire groups: #{e.message}"
      UI.messagebox("Error ungroup wire groups: #{e.message}")
    end
  end

  module LineTransformation
    def self.explode_wire_groups(line)
      wirings_hash = Lvm444Dev::SkpElectricsLinesManager.get_wirings_by_line(line)

      wirings_hash.each do |wire_type, groups|
        groups.each do |group|
          group.layer = nil
          group.explode
        end
      end
    end
  end
end
