require 'sketchup.rb'
require 'extensions.rb'

module Lvm444Dev
    # Класс для работы со справочником меток в SketchUp
  module TagsUtils

    # Gets all layers from a root folder and its subfolders
    # @param root_folder [Sketchup::LayerFolder] The starting folder
    # @param options [Hash] Search options
    # @option options [Boolean] :recursive (true) Whether to search subfolders
    # @option options [Regexp,Array<String>] :include Only include layers matching names
    # @option options [Regexp,Array<String>] :exclude Exclude layers matching names
    # @return [Array<Sketchup::Layer>] Collection of layer objects
    def self.get_layers_from_folder(root_folder, options = {})
      raise ArgumentError, "root_folder must be a Sketchup::LayerFolder" unless root_folder.is_a?(Sketchup::LayerFolder)

      options = {
        recursive: true,
        include: nil,
        exclude: nil
      }.merge(options)

      layers = []

      # Process layers in current folder
      root_folder.layers.each do |layer|
        next if excluded_layer?(layer, options[:exclude])
        next unless included_layer?(layer, options[:include])
        layers << layer
      end

      # Process subfolders if recursive
      if options[:recursive]
        root_folder.folders.each do |subfolder|
          layers += get_layers_from_folder(subfolder, options)
        end
      end

      layers
    end

    # Helper methods
    def self.excluded_layer?(layer, exclude_pattern)
      case exclude_pattern
      when Regexp then layer.name.match?(exclude_pattern)
      when Array then exclude_pattern.include?(layer.name)
      when String then layer.name == exclude_pattern
      else false
      end
    end

    def self.included_layer?(layer, include_pattern)
      return true if include_pattern.nil?

      case include_pattern
      when Regexp then layer.name.match?(include_pattern)
      when Array then include_pattern.include?(layer.name)
      when String then layer.name == include_pattern
      else false
      end
    end

    # Finds a root folder by exact name match
    # @param folder_name [String] Name of the root folder to find
    # @return [Sketchup::LayerFolder, nil] The found folder or nil
    def self.find_root_folder_by_name(model,folder_name)
      return nil unless model.valid?

      # Get all root folders (folders at the top level)
      root_folders = model.layers.folders

      # Find matching folder (case sensitive)
      root_folders.find { |folder| folder.name == folder_name }
    end

  end
end
