module Lvm444Dev
  class LineGroupSplitTool < Sketchup::Tools
    def initialize
      @cursor_id = UI.create_cursor(File.join(File.dirname(__FILE__), "cut-out.png"), 0, 0)
      @cutting_plane = nil
      @group_to_split = nil
      @cut_position = nil
      @cut_normal = nil
    end

    def activate
      Sketchup.status_text = "Выберите точку на группе из линий для разрезания"
      @model = Sketchup.active_model
      @selection = @model.selection
    end

    def deactivate(view)
      view.invalidate if @cutting_plane
    end

    def onMouseMove(flags, x, y, view)
      ph = view.pick_helper(x, y)
      ph.do_pick(x, y)

      picked_entity = ph.best_picked
      if picked_entity.is_a?(Sketchup::Edge) && (picked_entity.parent.is_a?(Sketchup::Group) || picked_entity.parent.is_a?(Sketchup::ComponentInstance))
        @group_to_split = picked_entity.parent
        @cut_position = ph.ray[0] + ph.ray[1] * ph.distance
        @cut_normal = calculate_cut_normal(picked_entity)

        update_cutting_plane(view)
        view.invalidate
      else
        @group_to_split = nil
        @cut_position = nil
      end
    end

    def onLButtonDown(flags, x, y, view)
      return unless @group_to_split && @cut_position && @cut_normal

      @model.start_operation("Разрезать группу линий", true)
      split_line_group(@group_to_split, @cut_position, @cut_normal)
      @model.commit_operation

      reset_tool
    end

    def draw(view)
      if @cutting_plane
        view.drawing_color = [255, 0, 0, 128]
        view.draw(GL_QUADS, @cutting_plane)

        view.drawing_color = [0, 255, 0]
        view.draw_points([@cut_position], 10, 1, "cross")
      end
    end

    def onSetCursor
      UI.set_cursor(@cursor_id)
    end

    private

    def calculate_cut_normal(edge)
      # Используем нормаль перпендикулярную линии и вертикали
      line_vector = edge.line[1]
      if line_vector.parallel?(Z_AXIS)
        # Если линия вертикальная, используем горизонтальную плоскость
        Geom::Vector3d.new(0, 0, 1)
      else
        # Создаем плоскость перпендикулярную линии
        line_vector.cross(Z_AXIS).normalize
      end
    end

    def update_cutting_plane(view)
      return unless @cut_position && @cut_normal

      size = 1000
      perp_vector = @cut_normal.axes[1]

      pt1 = @cut_position + perp_vector * size
      pt2 = @cut_position - perp_vector * size
      pt3 = pt2 + @cut_normal * size
      pt4 = pt1 + @cut_normal * size

      @cutting_plane = [pt1, pt2, pt3, pt4]
    end

    def split_line_group(group, position, normal)
      plane = [position, normal]

      # Создаем временную группу для результатов
      temp_group = group.parent.entities.add_group
      temp_group.entities.add_line(position, position + normal * 100)

      # Разделяем группу
      result = group.entities.intersect_with(
        false, # recursive
        group.transformation, # transformation
        temp_group.entities, # other_entities
        temp_group.transformation, # other_transformation
        true, # front_side_only
        plane # cutting_plane
      )

      # Удаляем временную группу
      temp_group.erase!

      if result
        # Создаем две новые группы
        front_group = group.parent.entities.add_group
        back_group = group.parent.entities.add_group

        # Разделяем линии по положению относительно плоскости
        group.entities.grep(Sketchup::Edge).each do |edge|
          start_pos = edge.start.position.transform(group.transformation)
          end_pos = edge.end.position.transform(group.transformation)

          start_side = (start_pos - position).dot(normal) >= 0
          end_side = (end_pos - position).dot(normal) >= 0

          if start_side && end_side
            # Линия полностью перед плоскостью
            front_group.entities.add_cline(edge.start.position, edge.end.position)
          elsif !start_side && !end_side
            # Линия полностью за плоскостью
            back_group.entities.add_cline(edge.start.position, edge.end.position)
          else
            # Линия пересекает плоскость - нужно разделить
            intersection = Geom.intersect_line_plane([edge.line[0].transform(group.transformation),
                                                    edge.line[1].transform(group.transformation)],
                                                   plane)
            if intersection
              front_group.entities.add_cline(start_side ? edge.start.position : intersection,
                                           start_side ? intersection : edge.end.position)
              back_group.entities.add_cline(start_side ? intersection : edge.start.position,
                                          start_side ? edge.end.position : intersection)
            end
          end
        end

        # Удаляем оригинальную группу
        group.erase!

        UI.messagebox("Группа линий успешно разделена")
      else
        UI.messagebox("Не удалось разделить группу")
      end
    end

    def reset_tool
      @cutting_plane = nil
      @group_to_split = nil
      @cut_position = nil
      @cut_normal = nil
      Sketchup.status_text = "Выберите точку на группе из линий для разрезания"
    end
  end
end

# Безопасная загрузка инструмента
begin
  unless file_loaded?(__FILE__)
    # Создаем панель инструментов
    toolbar = UI::Toolbar.new("Line Tools")

    # Создаем команду для инструмента
    cmd = UI::Command.new("Split Line Group") {
      Sketchup.active_model.select_tool(Lvm444Dev::LineGroupSplitTool.new)
    }

    puts "cmd #{cmd}"

    # Загружаем иконки
    begin
      icons_dir = File.join(File.dirname(__FILE__), "icons")
      icon_path = File.join(icons_dir, "split_lines.png")

      if File.exist?(icon_path)
        cmd.small_icon = icon_path
        cmd.large_icon = icon_path
      else
        # Используем стандартные иконки SketchUp если свои не найдены
        cmd.small_icon = "ToolPencil.png"
        cmd.large_icon = "ToolPencil.png"
        puts "Иконка не найдена: #{icon_path}"
      end
    rescue => e
      puts "Ошибка загрузки иконок: #{e.message}"
      cmd.small_icon = "ToolPencil.png"
      cmd.large_icon = "ToolPencil.png"
    end

    cmd.tooltip = "Разрезать группу линий по выбранной точке"
    toolbar.add_item(cmd)

    # Показываем панель инструментов
    toolbar.show

    file_loaded(__FILE__)
  end
rescue => e
  msg = "Ошибка загрузки плагина:\n#{e.message}\n\n#{e.backtrace.join("\n")}"
  puts msg
  UI.messagebox(msg)
end
