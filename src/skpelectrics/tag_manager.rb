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
      lines = Lvm444Dev::SkpElectricsLinesManager.search_electric_lines


      # Get the active model
      model = Sketchup.active_model

      layers = model.layers
      folders = layers.folders

      # Start an operation (for undo support)
      model.start_operation("redefine tags", true)
      root_folder = layers.add_folder("SkpElectrics")
        lines.each do |line|
          layer = layers.add(line.type)
          root_folder.add_layer(layer)
          line.get_group().layer = layer
        end
      model.commit_operation
    end
  end
end
