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

      tagsDict = Lvm444Dev::TagsDictionary.new(model)
      tagsDict.load_from_model

      materials = model.materials
      layers = model.layers
      folders = layers.folders

      root_folder = find_or_create_folder(model,"SkpElectrics")

      clear_folder(root_folder)
      remove_folder(model,root_folder,root_folder)

      # каталог меток по структуре справочника
      gtree = tagsDict.groups_tree

      groups_hash = {}
      gtree.each do |group|
        create_folder_by_group(root_folder,group,groups_hash)
      end

      layers_hash = {}
      materials_hash = {}

      groups_hash.each do |gpath,folder|
        tags = tagsDict.tags_for_group(gpath)
        tags.each do |line_type,tag|
          taglayer = layers.add_layer(line_type)
          taglayer.color = tag["color"]
          folder.add_layer(taglayer)

          # define material
          material = materials[line_type]
          if material == nil
            material = materials.add(line_type)
          end
          material.color = tag["color"]

          # set hash
          materials_hash[line_type] = material
          layers_hash[line_type] = taglayer
        end
      end
      lines = Lvm444Dev::SkpElectricsLinesManager.search_electric_lines

      lines.each do |line|
        line.get_group().layer = layers_hash[line.type]
        line.get_group().material = materials_hash[line.type]
      end

    end

    # move entities to layer
    def self.move_entities_from_layer(entities, layers_from,layer_to)
      layers_set = Set.new(layers_from.to_a)
      entities.grep(Sketchup::Entity).select do |entity|

        if (entity.is_a?(Sketchup::Group))
          move_entities_from_layer(entity.entities,layers_from,layer_to)
        end

        if layers_set.include?(entity.layer)
          entity.layer = layer_to
        end
      end
    end



    # clear folder

    def self.clear_folder(folder)
      puts "clear folder #{folder}"
      layers_to_clear = Lvm444Dev::TagsUtils.get_layers_from_folder(folder)

      model = Sketchup.active_model

      layer0 = model.layers[0] # Layer0 is always index 0

      move_entities_from_layer(model.entities,layers_to_clear,layer0)
    end

    def self.remove_folder(model,folder,exclude = nil)
      if folder
        # Move all layers to root level first
        folder.layers.each { |layer| folder.remove_layer(layer)}

        # Remove all subfolders recursively
        folder.folders.each { |subfolder| remove_folder(model,subfolder,nil) }

        # Remove the folder itself
        if (folder != exclude)
          puts "remove folder #{folder.name}"
          #model.layers.remove_folder(folder)
          parent = folder.parent
          parent.remove_folder(folder)
        end
      end
    end

    def self.create_folder_by_group(parentFolder,group,groups_hash)
      puts "inside #{parentFolder} - #{group["name"]}"

      gname = group["name"]

      pfolder = parentFolder.add_folder(gname)

      groups_hash[group["path"]] = pfolder

      group["children"].each do |childGroup|
        create_folder_by_group(pfolder,childGroup,groups_hash)
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

      root_folder = find_or_create_folder(model,"SkpElectricsWirings")

      wiring_group_hash.each_key do |wtype|
        layer = layers.add(wtype)
        root_folder.add_layer(layer)

        wiring_group_hash[wtype].each do |group|
          group.layer = layer

          entitites_to_clean = group.entities.grep(Sketchup::Drawingelement)

          entitites_to_clean.each do |entity|
            if entity.is_a?(Sketchup::Group)
              next
            end

            entity.layer = nil
          end
        end
      end

      model.commit_operation
    end

    def self.find_or_create_folder(model,folder_name)
      root_folder = Lvm444Dev::TagsUtils.find_root_folder_by_name(model,folder_name)

      if (root_folder == nil)
        root_folder = layers.add_folder(folder_name)
      end
      root_folder
    end
  end
end
