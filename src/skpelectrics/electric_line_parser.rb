module Lvm444Dev
  module SketchupUtils

    require_relative 'dialog_settings'


    module ElectricLineParser
      def self.parse_group(group)
        pattern_number = Lvm444Dev::SkpElectrics::Settings.get_line_template

        case pattern_number
        when "1"
          pattern = /^(?<line_number>\d+)-(?<load_type>[А-ЯA-Z\d]{1,3})-(?<room>[А-яA-Za-z\d]+)\s*(?: (?<description>.+))?$/
        when "2"
          pattern = /^(?<line_number>[1-9][0-9]?)(?<load_type>[А-Яа-яA-Za-z]+)(?<room>[1-9][0-9]?)(?<description>\s.*)?$/
        else
          UI.messagebox("Выбран некорректный номер шаблона #{pattern_number}")
          raise "parser error unknown pattern num #{pattern_number}"
        end

        #puts "pattern #{pattern.to_json}"

        if match = group.name.match(pattern)
          elLine = ElectricLineModel.new(group)
          elLine.line_number = match[:line_number]
          elLine.type = match[:load_type]
          elLine.room = match[:room]
          elLine.description = match[:description]
          elLine
        else
          return nil
        end
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

    def length
      Lvm444Dev::SketchupUtils.calculate_length_by_entity(@group)
    end

    def wire_type_sums
      return Lvm444Dev::SketchupUtils.calculate_length_by_attribute(@group,"wiring")
    end

    private
    def check
    end
  end
end


