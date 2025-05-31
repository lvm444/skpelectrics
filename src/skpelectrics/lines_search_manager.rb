module Lvm444Dev
  module SkpElectricsLinesManager

    def self.search_electric_lines
      model = Sketchup.active_model
      root_groups = model.entities.grep(Sketchup::Group)

      lines = []
      root_groups.each do |group|
        lines.concat(search_line(group))
      end

      lines
    end

    def self.search_line(group)
      electric_line = Lvm444Dev::SketchupUtils::ElectricLineParser.parse_group group

      if electric_line != nil
        return [electric_line]
      else
        lines = []
        group.entities.grep(Sketchup::Group).each do |group|
          lines.concat(self.search_line(group))
        end
        return lines
      end
    end

    def self.search_wire_tap_groups
      model = Sketchup.active_model
      root_groups = model.entities.grep(Sketchup::Group)

      lines = []
      root_groups.each do |group|
        lines.concat(search_line(group))
      end

      lines
    end

  end
end


