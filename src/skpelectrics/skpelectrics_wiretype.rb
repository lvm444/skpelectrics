module Lvm444Dev
  module SkpElectricsWireType
    def self.edit_wiring_type(wtype)
      if is_one_group_selected()
        group = get_first_selected_group()
        self.set_entity_attribute(group,"wiring",wtype)
        puts "group #{group} set wtype = #{wtype}"
      elsif is_one_or_more_entities_selected()
        puts "create group set wtype = #{wtype}"
        create_specific_subgroupe(wtype,{:wiring=>wtype})
      else
        UI.messagebox("Выделение не корректно. попробуйте выделить заново и повторить")
      end
    end

    def self.get_first_selected_group()
      model = Sketchup.active_model
      selection = model.selection

      if selection.length == 1 && selection.first.is_a?(Sketchup::Group)
        return selection.first
      end

      return nil
    end

    def self.create_wire_types_by_electric_lines(wtype,lines)
      lines.each do |line|
        edit_wiring_type_in_elctric_line(wtype,line)
      end
    end

    def self.edit_wiring_type_in_elctric_line(wtype, electric_line)

      group = electric_line.get_group

      edges = group.entities.grep(Sketchup::Edge)

      if edges.count>0
        Lvm444Dev::SkpElectricsGroupManager.create_line_subgroups(group,wtype,edges,{:wiring=>wtype})
      end
    end
  end
end
