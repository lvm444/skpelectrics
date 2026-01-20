# Copyright 2025 Lvm444Dev
# Генератор сетки привязки для SketchUp плагина skpelectrics

require 'sketchup.rb'

module Lvm444Dev
  module GridGenerator

    class GridTool

      def initialize
        @points = []
        @grid_size = 26.0.mm   # шаг сетки по умолчанию 26 мм
        @margin = 100.0.mm     # отступ от краев по умолчанию 100 мм
        @plane = nil
        @width = 0
        @height = 0
        @mouse_ip = Sketchup::InputPoint.new
        @state = :select_plane  # :select_plane, :drag_grid, :done
        @drawn_grid = nil
      end

      def activate
        Sketchup.status_text = "Выберите плоскость для сетки: кликните 3 точки или нажмите Enter для плоскости по умолчанию (XY)"
        @points.clear
        @state = :select_plane
        @plane = nil
        @width = 0
        @height = 0
      end

      def deactivate(view)
        view.invalidate if @drawn_grid
        @drawn_grid = nil
      end

      def resume(view)
        view.invalidate
      end

      def suspend(view)
        view.invalidate
      end

      def onCancel(reason, view)
        view.invalidate
        Sketchup.status_text = "Генератор сетки отменен"
        Sketchup.active_model.select_tool(nil)
      end

      def onKeyDown(key, repeat, flags, view)
        case key
        when UI::KeyReturn
          if @state == :select_plane && @points.empty?
            # Используем плоскость XY по умолчанию
            @plane = [Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 0, 1)]
            @state = :drag_grid
            Sketchup.status_text = "Задайте размер сетки: кликните и растяните прямоугольник"
            view.invalidate
            return true
          end
        when UI::KeyEscape
          onCancel(0, view)
          return true
        end
        false
      end

      def onMouseMove(flags, x, y, view)
        @mouse_ip.pick(view, x, y)

        case @state
        when :select_plane
          if @points.size == 1
            # Показываем линию от первой точки
            view.tooltip = @mouse_ip.tooltip
          elsif @points.size == 2
            # Показываем плоскость
            view.tooltip = @mouse_ip.tooltip
          end
        when :drag_grid
          if @points.size == 3
            # Третья точка - это начало сетки, четвертая - противоположный угол
            start = @points[2]
            current = @mouse_ip.position

            # Проекция на плоскость
            if @plane
              normal = @plane[1]
              plane_origin = @plane[0]
              current_proj = project_to_plane(current, plane_origin, normal)
              start_proj = project_to_plane(start, plane_origin, normal)

              @width = (current_proj.x - start_proj.x).abs
              @height = (current_proj.y - start_proj.y).abs

              # Вычисляем количество ячеек
              cells_x = (@width / @grid_size).ceil
              cells_y = (@height / @grid_size).ceil

              Sketchup.status_text = "Сетка: #{cells_x} x #{cells_y} ячеек, шаг: #{@grid_size.to_mm} мм"
              view.tooltip = "Шаг: #{@grid_size.to_mm} мм, Ячеек: #{cells_x} x #{cells_y}, Ширина: #{@width.to_mm} мм, Высота: #{@height.to_mm} мм"
            end
          end
        end

        view.invalidate
      end

      def onLButtonDown(flags, x, y, view)
        case @state
        when :select_plane
          @points << @mouse_ip.position

          case @points.size
          when 1
            Sketchup.status_text = "Выберите вторую точку для определения плоскости"
          when 2
            Sketchup.status_text = "Выберите третью точку для определения плоскости"
          when 3
            # Три точки определяют плоскость
            @plane = define_plane(@points[0], @points[1], @points[2])
            @state = :drag_grid
            Sketchup.status_text = "Задайте размер сетки: кликните и растяните прямоугольник"
          end

        when :drag_grid
          if @points.size == 3
            # Четвертый клик - завершение создания сетки
            @points << @mouse_ip.position
            create_grid
            @state = :done
            Sketchup.status_text = "Сетка создана. Нажмите Esc для выхода или кликните для новой сетки."
          end
        when :done
          # Начинаем заново
          reset_tool
          onLButtonDown(flags, x, y, view)
        end

        view.invalidate
        true
      end

      def draw(view)
        # Рисуем временную геометрию
        case @state
        when :select_plane
          draw_plane_selection(view)
        when :drag_grid
          draw_grid_preview(view)
        end

        # Рисуем мышиный указатель
        @mouse_ip.draw(view) if @mouse_ip.valid?
      end

      private

      def define_plane(p1, p2, p3)
        # Создаем плоскость из трех точек
        vector1 = p2 - p1
        vector2 = p3 - p1
        normal = vector1 * vector2  # cross product

        # Если точки коллинеарны, используем плоскость XY по умолчанию
        if normal.length == 0
          normal = Geom::Vector3d.new(0, 0, 1)
        else
          normal.normalize!
        end
        [p1, normal]
      end

      def project_to_plane(point, plane_origin, normal)
        normal = Geom::Vector3d.new(normal) unless normal.is_a?(Geom::Vector3d)
        normal.normalize!

        plane_origin = Geom::Point3d.new(plane_origin) unless plane_origin.is_a?(Geom::Point3d)
        point = Geom::Point3d.new(point) unless point.is_a?(Geom::Point3d)

        vector = point - plane_origin
        distance = vector.dot(normal)

        point.offset(normal, -distance)
      end

      def draw_plane_selection(view)
        return if @points.empty?

        # Рисуем выбранные точки
        view.line_stipple = ''
        view.line_width = 2
        view.drawing_color = Sketchup::Color.new(255, 0, 0)

        @points.each do |point|
          view.draw_points(point, 10, 2)  # 2 = cross marker
        end

        # Рисуем линии между точками
        if @points.size >= 2
          view.draw(GL_LINES, @points[0], @points[1])
        end
        if @points.size == 3
          view.draw(GL_LINES, @points[1], @points[2])
          view.draw(GL_LINES, @points[2], @points[0])
        end
      end

      def draw_grid_preview(view)
        return if @points.size < 3 || !@plane

        start = @points[2]
        plane_origin = @plane[0]
        normal = @plane[1]

        # Проекция текущей позиции мыши на плоскость
        current = @mouse_ip.position
        current_proj = project_to_plane(current, plane_origin, normal)
        start_proj = project_to_plane(start, plane_origin, normal)

        # Определяем углы прямоугольника
        min_x = [start_proj.x, current_proj.x].min
        max_x = [start_proj.x, current_proj.x].max
        min_y = [start_proj.y, current_proj.y].min
        max_y = [start_proj.y, current_proj.y].max

        # Вычисляем внутреннюю область с учетом отступа
        inner_min_x = min_x + @margin
        inner_max_x = max_x - @margin
        inner_min_y = min_y + @margin
        inner_max_y = max_y - @margin

        # Убедимся, что внутренняя область не вырождена
        inner_min_x = inner_max_x if inner_min_x > inner_max_x
        inner_min_y = inner_max_y if inner_min_y > inner_max_y

        # Рисуем прямоугольник
        view.line_stipple = ''
        view.line_width = 1
        view.drawing_color = Sketchup::Color.new(0, 0, 255)

        corners = [
          Geom::Point3d.new(min_x, min_y, start_proj.z),
          Geom::Point3d.new(max_x, min_y, start_proj.z),
          Geom::Point3d.new(max_x, max_y, start_proj.z),
          Geom::Point3d.new(min_x, max_y, start_proj.z)
        ]

        # Линии прямоугольника
        view.draw(GL_LINE_LOOP, corners)

        # Рисуем сетку (только внутри внутренней области)
        view.drawing_color = Sketchup::Color.new(255, 0, 0, 128)  # полупрозрачный красный
        view.line_width = 1
        view.line_stipple = '.'

        # Вертикальные линии
        x = inner_min_x
        while x <= inner_max_x + 0.001
          view.draw(GL_LINES,
                   Geom::Point3d.new(x, inner_min_y, start_proj.z),
                   Geom::Point3d.new(x, inner_max_y, start_proj.z))
          x += @grid_size
        end

        # Горизонтальные линии
        y = inner_min_y
        while y <= inner_max_y + 0.001
          view.draw(GL_LINES,
                   Geom::Point3d.new(inner_min_x, y, start_proj.z),
                   Geom::Point3d.new(inner_max_x, y, start_proj.z))
          y += @grid_size
        end

        # Отображаем шаг сетки
        if @width > 0 && @height > 0
          # Количество ячеек с учетом отступа
          inner_width = [inner_max_x - inner_min_x, 0].max
          inner_height = [inner_max_y - inner_min_y, 0].max
          cells_x = (inner_width / @grid_size).ceil
          cells_y = (inner_height / @grid_size).ceil

          text_point = Geom::Point3d.new(max_x + 0.5.m, max_y + 0.5.m, start_proj.z)
          view.draw_text(text_point, "Шаг: #{@grid_size.to_mm} мм, Отступ: #{@margin.to_mm} мм\nЯчеек: #{cells_x} x #{cells_y}")
        end
      end

      def create_grid
        return if @points.size < 4 || !@plane

        model = Sketchup.active_model
        model.start_operation('Создать сетку привязки', true)

        start = @points[2]
        plane_origin = @plane[0]
        normal = @plane[1]

        # Проекция конечной точки на плоскость
        current = @points[3]
        current_proj = project_to_plane(current, plane_origin, normal)
        start_proj = project_to_plane(start, plane_origin, normal)

        # Определяем границы
        min_x = [start_proj.x, current_proj.x].min
        max_x = [start_proj.x, current_proj.x].max
        min_y = [start_proj.y, current_proj.y].min
        max_y = [start_proj.y, current_proj.y].max

        # Вычисляем внутреннюю область с учетом отступа
        inner_min_x = min_x + @margin
        inner_max_x = max_x - @margin
        inner_min_y = min_y + @margin
        inner_max_y = max_y - @margin

        # Убедимся, что внутренняя область не вырождена
        inner_min_x = inner_max_x if inner_min_x > inner_max_x
        inner_min_y = inner_max_y if inner_min_y > inner_max_y

        # Создаем группу для сетки
        entities = model.active_entities
        group = entities.add_group
        group.name = "Сетка привязки #{Time.now.strftime('%H:%M:%S')}"

        # Создаем линии сетки (только внутри внутренней области)
        edges = []

        # Вертикальные линии
        x = inner_min_x
        while x <= inner_max_x + 0.001
          p1 = Geom::Point3d.new(x, inner_min_y, start_proj.z)
          p2 = Geom::Point3d.new(x, inner_max_y, start_proj.z)
          edge = group.entities.add_line(p1, p2)
          edge.set_attribute("grid", "vertical", true)
          edges << edge
          x += @grid_size
        end

        # Горизонтальные линии
        y = inner_min_y
        while y <= inner_max_y + 0.001
          p1 = Geom::Point3d.new(inner_min_x, y, start_proj.z)
          p2 = Geom::Point3d.new(inner_max_x, y, start_proj.z)
          edge = group.entities.add_line(p1, p2)
          edge.set_attribute("grid", "horizontal", true)
          edges << edge
          y += @grid_size
        end

        # Добавляем атрибуты
        inner_width = [inner_max_x - inner_min_x, 0].max
        inner_height = [inner_max_y - inner_min_y, 0].max
        cells_x = (inner_width / @grid_size).ceil
        cells_y = (inner_height / @grid_size).ceil

        group.set_attribute("grid", "step", @grid_size)
        group.set_attribute("grid", "margin", @margin)
        group.set_attribute("grid", "width", max_x - min_x)
        group.set_attribute("grid", "height", max_y - min_y)
        group.set_attribute("grid", "inner_width", inner_width)
        group.set_attribute("grid", "inner_height", inner_height)
        group.set_attribute("grid", "cells_x", cells_x)
        group.set_attribute("grid", "cells_y", cells_y)
        group.set_attribute("grid", "plane_normal", normal.to_a)
        group.set_attribute("grid", "plane_origin", plane_origin.to_a)

        model.commit_operation

        # Выделяем созданную сетку
        model.selection.clear
        model.selection.add(group)

        Sketchup.status_text = "Сетка создана: #{group.name}"
        @drawn_grid = group
      end

      def reset_tool
        @points.clear
        @state = :select_plane
        @plane = nil
        @width = 0
        @height = 0
        @drawn_grid = nil
        Sketchup.status_text = "Выберите плоскость для сетки: кликните 3 точки или нажмите Enter для плоскости по умолчанию (XY)"
      end

    end # class GridTool

    # Диалог для настройки шага сетки
    module GridSettings
      def self.show_dialog
        prompts = ["Шаг сетки (мм):", "Отступ от краев (мм):"]
        defaults = ["26.0", "100.0"]
        results = UI.inputbox(prompts, defaults, "Настройки сетки")

        if results
          step = results[0].to_f.mm
          margin = results[1].to_f.mm
          # Сохраняем в настройки
          model = Sketchup.active_model
          model.set_attribute("skpelectrics_grid", "step", step)
          model.set_attribute("skpelectrics_grid", "margin", margin)
          return step, margin
        end
        nil
      end

      def self.get_step
        model = Sketchup.active_model
        step = model.get_attribute("skpelectrics_grid", "step")
        step ? step : 26.0.mm
      end

      def self.get_margin
        model = Sketchup.active_model
        margin = model.get_attribute("skpelectrics_grid", "margin")
        margin ? margin : 100.0.mm
      end
    end

    # Основные методы для интеграции с плагином
    def self.activate_grid_tool
      tool = GridTool.new
      Sketchup.active_model.select_tool(tool)
    end

    def self.show_settings
      result = GridSettings.show_dialog
      if result
        UI.messagebox("Параметры сетки установлены: шаг #{result[0].to_mm} мм, отступ #{result[1].to_mm} мм")
      end
    end

  end # module GridGenerator
end # module Lvm444Dev
