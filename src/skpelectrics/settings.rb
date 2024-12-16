module Lvm444Dev

  module SkpElectrics

    require 'sketchup.rb'

    module Settings

      unless defined?(SETTINGS_KEY)
        SETTINGS_KEY = "skpelectrics_settings".freeze
      end

      def self.get_model()
        return Sketchup.active_model
      end

      # настройка шаблона парсера
      def self.get_line_template
        return get_setting_by_name("line_template_setup")
      end

      def self.set_line_template(new_template_num)
        set_setting_by_name("line_template_setup",new_template_num)
      end


      def self.init_settings
        init_if_not_define("line_template_setup",1)
      end

      def self.init_if_not_define(setting_name,setting_value)
        value = get_setting_by_name(setting_name)
        if value == nil
          set_setting_by_name(setting_name,setting_value)
        end
      end

      def self.get_setting_by_name(settings_name)
        return get_model().get_attribute(SETTINGS_KEY,settings_name)
      end

      def self.set_setting_by_name(settings_name,setting_value)
        return get_model().set_attribute(SETTINGS_KEY,settings_name,setting_value)
      end

      unless file_loaded?(__FILE__)
        puts "before init"
        init_settings
        puts "after init"
      end



    end
  end
end
