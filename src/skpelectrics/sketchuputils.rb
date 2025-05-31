module Lvm444Dev

  require 'sketchup.rb'
  require_relative 'dialog_settings'

  module SketchupUtils

    INCH_SCALE ||= 0.0254

    def self.calculate_length_by_attribute(group,attribute_name)
      scale = 0.0254
      entities = group.entities

      attribute_sums = Hash.new(0.0) # Default to 0.0 for any new key
      entities.each do |entity|

        attribute_value = entity.get_attribute("dynamic_attributes", "wiring")
        next if attribute_value==nil

        entity_length = 0
        if entity.is_a?(Sketchup::Edge)
          entity_length += entity.length
        elsif entity.is_a?(Sketchup::Group)
          entity.entities.grep(Sketchup::Edge).each do |edge|
            entity_length += edge.length
          end
        end

        attribute_sums[attribute_value] += entity_length * scale

      end

      attribute_sums
    end

    # calculation

    def self.calculate_length_by_entity(entity)
      res = 0.0
      if entity.is_a?(Sketchup::Group)
        group = entity
        group.entities.each do |entity|
          res += self.calculate_length_by_entity(entity).to_f
        end
        return res
      elsif entity.is_a?(Sketchup::Edge)
        return entity.length * INCH_SCALE
      end
    end

    def self.get_skp_model
      Sketchup.active_model
    end

    def self.calculate_selected()
      model = Sketchup.active_model
      selection = model.selection

      if selection.length == 1 && selection.first.is_a?(Sketchup::Group)
        specific_group = selection.first
        puts "группа #{specific_group.name} "
        sum = self.calculate_length_by_entity(specific_group)

        puts "sum #{sum}"
      else
        UI.messagebox("Please select a single group to grep entities from.")
      end
    end

    # entities selection

    def self.get_selected_group()
      model = Sketchup.active_model
      selection = model.selection

      if selection.length == 1 && selection.first.is_a?(Sketchup::Group)
        return selection.first
      end

      return nil
    end

    def self.get_selected_entities()
      model = Sketchup.active_model
      selection = model.selection

      if selection.length > 1 && selection.first.is_a?(Sketchup::Edge)
        return selection
      end

    end

    def self.is_one_group_selected()
      model = Sketchup.active_model
      selection = model.selection

      if selection.length == 1 && selection.first.is_a?(Sketchup::Group)
        return true
      end

      return false
    end

    def self.is_one_or_more_entities_selected()
      model = Sketchup.active_model
      selection = model.selection

      if selection.length > 0
        return true
      end

      return false
    end

    # dynamic attributes

    def self.get_entity_attribute(entity,attribute_name)
      return entity.get_attribute("dynamic_attributes", attribute_name)
    end

    def self.set_entity_attribute(entity,attribute_name,attribute_value)
      return entity.set_attribute("dynamic_attributes", attribute_name,attribute_value)
    end

    # edit groups

    def self.create_group(group_name)
      model = Sketchup.active_model
      selection = model.selection

      if ((selection.length > 0) && (selection.length < 10))
        res=model.entities.add_group(selection.to_a)
        res.name = group_name
        return res
      else
        UI.messagebox("выберите от 1 до 10 элементов для создания группы")
      end
    end

    def self.create_specific_subgroupe(group_name,attributes={})
      group = create_group(group_name)
      if (attributes.length>0)
        attributes.each do |attr_name,attr_value|
          res = group.set_attribute "dynamic_attributes", attr_name,attr_value
        end
      end
    end


    # search lines

    def self.search_wtypes
      lines = search_electric_lines
      types = get_wiring_types(lines)
      types
    end

    def self.search_electric_lines
      model = Sketchup.active_model
      root_groups = model.entities.grep(Sketchup::Group)

      lines = []
      root_groups.each do |group|
        lines.concat(search_line(group))
      end

      lines
    end

    def self.get_wiring_types(results)
      wtypes = Hash.new(0)
      results.each do |electric_line|
        electric_line.wire_type_sums.each do |wtype,len|
          wtypes[wtype] += len
        end
      end
      wtypes
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

    def self.create_wiring_method_group(group_name, wiring_meth)
      create_specific_subgroupe(group_name,{:wiring=>wiring_meth})
    end

    def self.get_selected_wiring_type()
      if (is_one_group_selected())
        group = get_selected_group()
        return get_entity_attribute(group,"wiring")
      elsif (is_one_or_more_entities_selected())
        return ""
      end
    end

  end
end
