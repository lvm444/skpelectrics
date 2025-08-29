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

    def self.get_rooms
      lines = search_electric_lines
      rooms = []
      lines.each do |line|
        rooms.push(line.room) unless rooms.include?(line.room)
      end
      rooms
    end

    def self.search_wire_tap_groups
      lines = search_electric_lines
      wiring_type_hash = Hash.new()

      lines.each do |line|
        line_wirings_hash = get_wirings_by_line(line)
        line_wirings_hash.each_key do |key|
          if !wiring_type_hash.key?(key)
            wiring_type_hash[key] = []
          end
          wiring_type_hash[key] = wiring_type_hash[key].concat(line_wirings_hash[key])
        end
      end

      wiring_type_hash
    end

    def self.get_wirings_by_line(line)
      line_group = line.get_group
      line_subgroups = line_group.entities.grep(Sketchup::Group)

      wiring_group_hash = Hash.new()

      line_subgroups.each do |group|
        wiring_type = group.get_attribute("dynamic_attributes", "wiring")
        next if wiring_type==nil

        if !wiring_group_hash.key?(wiring_type)
            wiring_group_hash[wiring_type] = []
        end

        wiring_group_hash[wiring_type].push(group)
      end

      wiring_group_hash
    end

  end
end


