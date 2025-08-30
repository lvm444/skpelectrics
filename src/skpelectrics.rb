# Copyright 2016-2022 Trimble Inc
# Licensed under the MIT license

require 'sketchup.rb'
require 'extensions.rb'

module Lvm444Dev
  module SkpElectrics

  @@dev_dir = nil

  def self.set_dev_dir(path)
    @@dev_dir = path
    puts "Development directory set to: #{@@dev_dir}"
  end

  def self.choose_dev_dir
    #puts "old dev dir: #{@@dev_dir}"
    folder_path = UI.select_directory(
      title: "Select a Folder", # Title of the dialog
      directory: ENV['HOME']    # Default directory to open (can be customized)
    )
    ENV['SKPELECTRICS_DEV_FOLDER'] = folder_path

    self.reload_dev
  end

  def self.reload_dev
    unless @@dev_dir
      unless ENV['SKPELECTRICS_DEV_FOLDER']
        puts "Development directory not set. Use `MyExtension::DevReload.set_dev_dir('/path/to/dir')`"
        return
      else
        @@dev_dir = ENV['SKPELECTRICS_DEV_FOLDER']
      end
    end

    Dir.glob(File.join(@@dev_dir, '**', '*.rb')).each do |file|
      load file
      puts "reload file #{file} - ok"
    end
    puts "Reloaded all files from #{@@dev_dir}: #{Time.now}"
  end

  unless file_loaded?(__FILE__)
    ex = SketchupExtension.new('Skp electrics', 'skpelectrics/main')
    ex.description = 'Skp Electrics extension'
    ex.version     = '0.9.2'
    ex.copyright   = 'lvm444'
    ex.creator     = 'lvm444'
    Sketchup.register_extension(ex, true)
    file_loaded(__FILE__)
  end

  end # module HelloCube
end # module Examples
