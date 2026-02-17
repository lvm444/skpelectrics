module Lvm444Dev
  module SketchupUtils

    require_relative 'dialog_settings'


    module ElectricLineParser

      @injected_settings = nil

      def self.injected_settings
        # Lazy loading - ищем Settings при первом обращении
        if @injected_settings.nil? && defined?(Lvm444Dev::SkpElectrics::Settings)
          @injected_settings = Lvm444Dev::SkpElectrics::Settings
        end
        @injected_settings
      end

      def self.injected_settings=(value)
        @injected_settings = value
      end

      def self.parse_group(group)

        settings = injected_settings

        pattern_number = settings.get_line_template

        if pattern_number == nil
          raise "parser error unknown line pattern number"
          return
        end

        case pattern_number.to_s
        when "1"
          pattern = /^(?<line_number>\d+)-(?<load_type>[А-ЯA-Z\d+(),]{1,10})-(?<room>[А-яA-Za-z\d]+)\s*(?: (?<description>.+))?$/
        when "2"
          pattern = /^(?<line_number>[1-9][0-9]?)(?<load_type>[А-Яа-яA-Za-z]+)(?<room>[1-9][0-9]?)(?<description>\s.*)?$/
        when "3"
          pattern = /^(?<room>[1-9][0-9]?)(?<load_type>[А-Яа-яA-Za-z]+)(?<group_in_room>[1-9][0-9]?)(?:\s*--\s*(?<description>.*))?$/
        else
          UI.messagebox("Выбран некорректный номер шаблона #{pattern_number}")
          raise "parser error unknown pattern num #{pattern_number}"
        end

        #puts "pattern #{pattern.to_json}"

        if match = group.name.match(pattern)
          elLine = ElectricLineModel.new(group)
          elLine.line_number = format_line_number(match)
          elLine.type = match[:load_type]
          elLine.room = match[:room]
          elLine.description = match[:description]
          elLine
        else
          return nil
        end
      end

      def self.format_line_number(match)
        if match.names.include?("line_number")
          return match[:line_number]
        end

        match[:room] + "." + match[:group_in_room].rjust(2, '0')
      end
    end
  end

  class ElectricLineModel

    attr_accessor :line_number, :type, :room, :description

    def initialize(group)
      @group = group
    end

    def as_json(options={})
        {
          line_number: @line_number,
          type: @type,
          room: @room,
          description: @description,
          length: length,
          wire_type_sums:wire_type_sums
        }
    end

    def to_json(*options)
        as_json(*options).to_json(*options)
    end

    def to_desc
      return "#{@group.name}"
    end

    def get_group
      return @group
    end

    def length
      Lvm444Dev::SketchupUtils.calculate_length_by_entity(@group)
    end

    def wire_type_sums
      return Lvm444Dev::TagsManager.calculate_length_by_attribute(@group,"wiring")
    end

    private
    def check
    end
  end
end


