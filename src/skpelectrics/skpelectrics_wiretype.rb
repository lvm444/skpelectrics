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
        edit_wiring_type_elctric_line(wtype,line)
      end
    end

    def self.edit_wiring_type_elctric_line(wtype,electric_line)

      group = electric_line.get_group

      edges = group.entities.grep(Sketchup::Edge)

      non_group_entities = group.entities.select { |e| !e.is_a?(Sketchup::Group) }

      if non_group_entities.count > 0
        Lvm444Dev::SkpElectricsGroupManager.create_line_subgroups(group,wtype,non_group_entities,{:wiring=>wtype})
      end
    end

    def self.create_wire_types_vh_by_electric_lines(horizontalType,verticalType,lines)
      puts "lines = #{lines}"

      lines.each do |line|
        edit_wiring_type_vh_elctric_line(horizontalType,verticalType,line)
      end
    end

    def self.edit_wiring_type_vh_elctric_line(horizontalType,verticalType,electric_line)

      group = electric_line.get_group

      edges = group.entities.grep(Sketchup::Edge)

      non_group_entities = group.entities.select { |e| !e.is_a?(Sketchup::Group) }
      non_group_vertical_edges = Lvm444Dev::SelectionManager.filter_vertical_edges(non_group_entities)
      non_group_horizontal_edges = Lvm444Dev::SelectionManager.filter_horizontal_edges(non_group_entities)

      if horizontalType != nil && non_group_horizontal_edges.count > 0
        Lvm444Dev::SkpElectricsGroupManager.create_line_subgroups(group,horizontalType,non_group_horizontal_edges,{:wiring=>horizontalType})
      end

      if verticalType != nil && non_group_vertical_edges.count > 0
        Lvm444Dev::SkpElectricsGroupManager.create_line_subgroups(group,verticalType,non_group_vertical_edges,{:wiring=>verticalType})
      end

    end

    def self.get_selected_type()
      if (is_one_group_selected())
        group = Lvm444Dev::SelectionManager.get_selected_group()
        return get_entity_attribute(group,"wiring")
      elsif (is_one_or_more_entities_selected())
        return ""
      end
    end

    def self.get_entity_attribute(entity,attribute_name)
      return entity.get_attribute("dynamic_attributes", attribute_name)
    end

    def self.set_entity_attribute(entity,attribute_name,attribute_value)
      return entity.set_attribute("dynamic_attributes", attribute_name,attribute_value)
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

    def self.get_selected_wiring_type()
      if (is_one_group_selected())
        #group = get_selected_group()
        #return get_entity_attribute(group,"wiring")
      elsif (is_one_or_more_entities_selected())
        return ""
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

    def self.create_group(group_name)
      model = Sketchup.active_model
      selection = model.selection

      if ((selection.length > 0) && (selection.length < 100))
        res=model.entities.add_group(selection.to_a)
        res.name = group_name
        return res
      else
        UI.messagebox("выберите от 1 до 10 элементов для создания группы")
      end
    end
  end
end
