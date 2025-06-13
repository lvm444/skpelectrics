require 'sketchup.rb'
require 'extensions.rb'

module Lvm444Dev
  module TagsManager
    def self.create_if_not_exists(tagname,parent_tag)
      model = Sketchup.active_model

      layers.add(layer_name) unless layers[layer_name]
    end

    def self.print_all_tags
      model = Sketchup.active_model
      puts "="*40
      puts "СПИСОК ТЕГОВ МОДЕЛИ:"

      layers = Sketchup.active_model.layers
      puts "layers #{layers}"
      puts "layers.count #{layers.count}"
      puts "layers folders count #{layers.count_folders}"
      layers.each_folder do |folder|
        puts "folder #{folder} - name #{folder.name}"
      end

      layers.each do |layer|
        puts "layer #{layer} - #{layer.name}"
      end

      puts "Всего тегов:"
      puts "="*40
    end

    def self.redefine_tags
      model = Sketchup.active_model
      model.start_operation("redefine tags", true)
      redefine_type_tags
      redefine_wiring_tags
      model.commit_operation
      rescue => e
        model.abort_operation
        puts "Failed to redefine_tags #{e.message}"
        UI.messagebox("Failed to redefine_tags: #{e.message}")
    end

    def self.redefine_type_tags

      lines = Lvm444Dev::SkpElectricsLinesManager.search_electric_lines
      # Get the active model
      model = Sketchup.active_model

      layers = model.layers
      folders = layers.folders

      # Start an operation (for undo support)

      root_folder = layers.add_folder("SkpElectrics")
        lines.each do |line|
          layer = layers.add(line.type)
          root_folder.add_layer(layer)
          line.get_group().layer = layer
        end


    end

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

    def self.redefine_wiring_tags
      wiring_group_hash = Lvm444Dev::SkpElectricsLinesManager.search_wire_tap_groups

      # Get the active model
      model = Sketchup.active_model

      layers = model.layers
      folders = layers.folders

      model.start_operation("redefine_wiring tags", true)
      root_folder = layers.add_folder("SkpElectricsWirings")

      wiring_group_hash.each_key do |wtype|
        layer = layers.add(wtype)
        root_folder.add_layer(layer)

        wiring_group_hash[wtype].each do |group|
          group.layer = layer
        end

      end

      model.commit_operation
    end

  end
end
