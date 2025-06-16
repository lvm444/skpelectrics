module Lvm444Dev
  module SelectionManager
    SELECTED_FACES ||= 1
    SELECTED_GROUPS ||= 2
    SELECTED_MIX ||= 3
    SELECTED_UNKNOWN ||= 4
    SELECTED_EDGES ||= 5
    SELECTED_ELECTRIC_LINES ||= 6

    def self.select_lines
      lines = Lvm444Dev::SkpElectricsLinesManager.search_electric_lines

      model = Sketchup.active_model

      model.selection.clear
      lines.each { |line| model.selection.add(line.get_group) }
    end

    def self.get_selection
      model = Sketchup.active_model
      selection = model.selection
      return selection
    end

    def self.get_one_level_selection_type
      selection_stats_hash = get_selection_types_stat

      puts "stats #{selection_stats_hash.to_json}"

      return interpret_result(selection_stats_hash)
    end

    def self.get_selected_groups
      selection = get_selection

      groups = selection.entries.grep(Sketchup::Group)

      return groups
    end

    def self.get_selected_group()
      model = Sketchup.active_model
      selection = model.selection

      if selection.length == 1 && selection.first.is_a?(Sketchup::Group)
        return selection.first
      end

      return nil
    end

    def self.filter_horizontal_edges(edges)
      horizontal_lines = []
      edges.grep(Sketchup::Edge).each do |edge|
        direction = edge.line[1]
        if direction.parallel?(Geom::Vector3d.new(1, 0, 0)) ||
          direction.parallel?(Geom::Vector3d.new(0, 1, 0)) ||
          (direction.z.abs < 1e-6 && direction.length > 0)
          horizontal_lines << edge
        end
      end
      horizontal_lines
    end

    def self.filter_vertical_edges(edges)
      vertical_lines = []
      edges.grep(Sketchup::Edge).each do |edge|
        direction = edge.line[1].normalize
        if direction.parallel?(Geom::Vector3d.new(0, 0, 1)) || (direction.z.abs > 1 - 1e-6)
          vertical_lines << edge
        end
      end
      vertical_lines
    end

    def self.get_selected_electric_lines
      groups = get_selected_groups

      lines = []

      groups.entries.each do |group|
        electric_line = Lvm444Dev::SketchupUtils::ElectricLineParser.parse_group group
        if electric_line != nil
          lines << electric_line
        end
      end
      lines
    end

    def self.interpret_result(selection_stats_hash)
      if ((selection_stats_hash[:faces]>0) && (selection_stats_hash[:groups]>0))
        return { selection_type: SELECTED_MIX, selected_count:selection_stats_hash[:total]}
      elsif ((selection_stats_hash[:faces] < 1) && (selection_stats_hash[:groups]>0))
        return { selection_type: SELECTED_GROUPS, selected_count: selection_stats_hash[:groups]}
      elsif ((selection_stats_hash[:faces] > 0) && (selection_stats_hash[:groups] < 1))
        return { selection_type: SELECTED_FACES, selected_count: selection_stats_hash[:faces]}
      elsif ((selection_stats_hash[:edges] > 0) && (selection_stats_hash[:groups] < 1))
        return { selection_type: SELECTED_EDGES, selected_count: selection_stats_hash[:edges]}
      elsif (selection_stats_hash[:electric_lines] > 0)
        return { selection_type: SELECTED_ELECTRIC_LINES, selected_count: selection_stats_hash[:electric_lines]}
      end
      return { selection_type: SELECTED_UNKNOWN, selected_count:selection_stats_hash[:total]}
    end

    def self.get_selection_types_stat
      selection = get_selection

      results = {
        total: selection.count,
        groups: 0,
        electric_lines: 0,
        components: 0,
        component_instances: 0,
        faces: 0,
        edges: 0,
        guide_points: 0,
        guide_lines: 0,
        images: 0,
        text: 0,
        section_planes: 0,
        other: 0
      }

      selection.each do |entity|
        case entity
        when Sketchup::Group
          electric_line = Lvm444Dev::SketchupUtils::ElectricLineParser.parse_group entity
          if (electric_line != nil)
            results[:electric_lines] += 1
          else
            results[:groups] += 1
          end
        when Sketchup::ComponentInstance
          if entity.definition.behavior.is2d?
            results[:components] += 1
          else
            results[:component_instances] += 1
          end
        when Sketchup::Face
          results[:faces] += 1
        when Sketchup::Edge
          results[:edges] += 1
        when Sketchup::ConstructionPoint
          results[:guide_points] += 1
        when Sketchup::ConstructionLine
          results[:guide_lines] += 1
        when Sketchup::Image
          results[:images] += 1
        when Sketchup::Text
          results[:text] += 1
        when Sketchup::SectionPlane
          results[:section_planes] += 1
        else
          results[:other] += 1
        end
      end

      return results
    end
  end
end
