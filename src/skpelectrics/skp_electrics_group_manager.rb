module Lvm444Dev
  module SkpElectricsGroupManager
    def self.create_group(group_name,parent_group,selection)
      puts "create group by name #{group_name}"
      puts "selection #{selection}"
      res=parent_group.entities.add_group(selection.to_a)
      res.name = group_name
      return res
    end

    def self.create_specific_subgroupe(group_name,parent_group,selection,attributes={})
      group = create_group(group_name,parent_group,selection)
      if (attributes.length>0)
        attributes.each do |attr_name,attr_value|
          res = group.set_attribute "dynamic_attributes", attr_name,attr_value
        end
      end
    end

    def self.create_line_subgroups(parent_group,group_name,lines,attributes={})
      model = Sketchup.active_model
      model.start_operation('Create Line Subgroups', true)


      parent_group_original_name = parent_group.name
      subgroup = parent_group.entities.add_group
      subgroup.name = group_name

      lines.each do |line|
        # Create new subgroup INSIDE the parent group

        next unless line.valid?

        next if line.is_a?(Sketchup::ConstructionPoint)
        # CORRECT WAY to move the line:
        # 1. Convert edge to a curve (array of edges)
        curve = [line]
        # 2. Use entities.add_curve to recreate it in the subgroup
        new_edges = subgroup.entities.add_curve(line.start.position, line.end.position)
        # 3. Delete original edge
        parent_group.entities.erase_entities(line)
      end

      if (attributes.length>0)
        attributes.each do |attr_name,attr_value|
          res = subgroup.set_attribute "dynamic_attributes", attr_name,attr_value
        end
      end

      if parent_group.name != parent_group_original_name
        puts "#{parent_group.name} != #{parent_group_original_name}"
        model.abort_operation
        raise 'parent group name dropped #{parent_group.name}'
      end

      model.commit_operation
    rescue => e
      model.abort_operation
      puts "Error creating subgroups: #{e.message}"
      UI.messagebox("Failed to create subgroups: #{e.message}")
    end
  end
end
