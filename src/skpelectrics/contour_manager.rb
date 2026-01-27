# Copyright 2025 Lvm444Dev
# Менеджер контура для генератора сетки

require 'sketchup.rb'

module Lvm444Dev
  module GridGenerator
    class ContourManager
      attr_reader :points, :state, :plane
      attr_accessor :grid_size, :margin_left, :margin_right, :margin_top, :margin_bottom

      def initialize(plane = nil)
        @plane = plane
        @points = []  # Точки контура (в мировых координатах)
        @state = :select_contour  # :select_contour, :contour_done
        @grid_size = 26.0.mm
        @margin_left = 100.0.mm
        @margin_right = 100.0.mm
        @margin_top = 100.0.mm
        @margin_bottom = 100.0.mm
      end

      # Установить плоскость
      def plane=(plane)
        @plane = plane
      end

      # Добавить точку контура (проецируем на плоскость)
      def add_point(point)
        return unless @plane

        # Проецируем точку на плоскость
        projected_point = project_to_plane(point, @plane[0], @plane[1])
        @points << projected_point
      end

      # Удалить последнюю точку контура
      def remove_last_point
        @points.pop unless @points.empty?
      end

      # Очистить точки контура
      def clear_points
        @points.clear
      end

      # Количество точек контура
      def point_count
        @points.size
      end

      # Проверить, можно ли завершить контур (минимум 2 точки)
      def can_finish?
        @points.size >= 2
      end

      # Завершить контур и создать сетку
      def finish_contour
        return nil unless can_finish?
        @state = :contour_done
        create_grid
      end

      # Проверить прилипание к первой точке контура
      def should_snap_to_first_point?(mouse_point, view, snap_pixels = 10)
        return false unless @points.size >= 2

        first_point = @points.first
        screen_point1 = view.screen_coords(first_point)
        screen_point2 = view.screen_coords(mouse_point)
        screen_distance = Math.sqrt((screen_point2.x - screen_point1.x)**2 + (screen_point2.y - screen_point1.y)**2)

        screen_distance <= snap_pixels
      end

      # Замкнуть контур (добавить копию первой точки) и создать сетку
      def close_contour
        return nil unless @points.size >= 2
        @points << @points.first
        @state = :contour_done
        create_grid
      end

      # Проверить, достигнут ли максимум точек
      def max_points_reached?(max_points = 50)
        @points.size >= max_points
      end

      # Нарисовать предпросмотр контура
      def draw_preview(view, mouse_ip = nil)
        return if @points.empty? || !@plane

        # Рисуем точки контура и линии между ними
        view.line_stipple = ''
        view.line_width = 2
        view.drawing_color = Sketchup::Color.new(255, 165, 0)  # оранжевый

        # Рисуем точки контура
        @points.each do |point|
          view.draw_points(point, 10, 2)  # 2 = cross marker
        end

        # Рисуем линии между точками контура
        if @points.size >= 2
          (0..@points.size-2).each do |i|
            view.draw(GL_LINES, @points[i], @points[i+1])
          end
          # Если контур завершен, рисуем линию от последней точки к первой
          if @state == :contour_done && @points.size >= 3
            view.draw(GL_LINES, @points.last, @points.first)
          end
        end

        # Визуальная обратная связь для прилипания
        if @state == :select_contour && @points.size >= 2 && mouse_ip && mouse_ip.valid?
          mouse_point = mouse_ip.position
          first_point = @points.first

          # Проверяем расстояние в экранных координатах
          screen_point1 = view.screen_coords(first_point)
          screen_point2 = view.screen_coords(mouse_point)
          screen_distance = Math.sqrt((screen_point2.x - screen_point1.x)**2 + (screen_point2.y - screen_point1.y)**2)

          if screen_distance <= 10  # 10 пикселей
            # Рисуем квадрат прилипания
            view.drawing_color = Sketchup::Color.new(0, 255, 0, 128)  # полупрозрачный зеленый
            size = 5.mm
            points = [
              first_point.offset(Geom::Vector3d.new(size, size, 0)),
              first_point.offset(Geom::Vector3d.new(-size, size, 0)),
              first_point.offset(Geom::Vector3d.new(-size, -size, 0)),
              first_point.offset(Geom::Vector3d.new(size, -size, 0)),
              first_point.offset(Geom::Vector3d.new(size, size, 0))
            ]
            view.draw(GL_LINE_STRIP, points)
            view.draw_points(first_point, 15, 1)  # 1 = square marker

            # Подсказка о замыкании
            view.tooltip = "Кликните для замыкания контура (близко к первой точке)"
          else
            view.tooltip = "Точек контура: #{@points.size}. Нажмите Enter для завершения или кликните близко к первой точке для замыкания."
          end
        elsif @state == :contour_done
          view.tooltip = "Контур завершен. Нажмите Enter для создания сетки."
        end

        # Рисуем проекцию мышиной точки на плоскость (если есть мышь)
        if @state == :select_contour && mouse_ip && mouse_ip.valid?
          mouse_point = mouse_ip.position
          projected_mouse = project_to_plane(mouse_point, @plane[0], @plane[1])

          # Маленький крестик для проекции
          view.drawing_color = Sketchup::Color.new(0, 255, 255, 200)  # голубой, полупрозрачный
          view.draw_points(projected_mouse, 6, 2)  # 2 = cross marker

          # Линия от мыши к проекции (если точка не на плоскости)
          distance = mouse_point.distance(projected_mouse)
          if distance > 1.mm
            view.line_stipple = '.'
            view.line_width = 1
            view.draw(GL_LINES, mouse_point, projected_mouse)
          end
        end

        # Предупреждение о слишком большом количестве точек
        if @points.size > 50
          view.drawing_color = Sketchup::Color.new(255, 0, 0)
          view.draw_text(@points.last, "Слишком много точек! Максимум 50. Нажмите Enter для завершения.")
        end
      end

      # Создать сетку внутри контура
      def create_grid
        return unless @plane && @points.size >= 2
        return unless @state == :contour_done

        model = Sketchup.active_model
        model.start_operation('Создать контурную сетку', true)

        transformation = @plane[2]
        transformation_inv = @plane[3]
        plane_origin = @plane[0]
        normal = @plane[1]

        # Преобразуем точки контура в локальные координаты
        contour_points_local = @points.map { |p| point_to_local(p, transformation_inv) }

        # Находим ограничивающий прямоугольник контура
        min_x = contour_points_local.map(&:x).min
        max_x = contour_points_local.map(&:x).max
        min_y = contour_points_local.map(&:y).min
        max_y = contour_points_local.map(&:y).max

        # Применяем отступы (используем левый и правый отступы для X, верхний и нижний для Y)
        left = min_x + @margin_left
        right = max_x - @margin_right
        bottom = min_y + @margin_bottom
        top = max_y - @margin_top

        # Убедимся, что внутренняя область не вырождена
        left = right if left > right
        bottom = top if bottom > top

        inner_min_x = left
        inner_max_x = right
        inner_min_y = bottom
        inner_max_y = top

        # Создаем группу для сетки
        entities = model.active_entities
        group = entities.add_group
        group.name = "Контурная сетка #{Time.now.strftime('%H:%M:%S')}"

        # Создаем линии сетки (прямоугольная сетка внутри ограничивающего прямоугольника)
        edges = []

        # Вертикальные линии
        x = inner_min_x
        while x <= inner_max_x + 0.001
          p1_local = Geom::Point3d.new(x, inner_min_y, 0)
          p2_local = Geom::Point3d.new(x, inner_max_y, 0)
          p1_world = point_from_local(p1_local, transformation)
          p2_world = point_from_local(p2_local, transformation)
          edge = group.entities.add_line(p1_world, p2_world)
          edge.set_attribute("grid", "vertical", true)
          edges << edge
          x += @grid_size
        end

        # Горизонтальные линии
        y = inner_min_y
        while y <= inner_max_y + 0.001
          p1_local = Geom::Point3d.new(inner_min_x, y, 0)
          p2_local = Geom::Point3d.new(inner_max_x, y, 0)
          p1_world = point_from_local(p1_local, transformation)
          p2_world = point_from_local(p2_local, transformation)
          edge = group.entities.add_line(p1_world, p2_world)
          edge.set_attribute("grid", "horizontal", true)
          edges << edge
          y += @grid_size
        end

        # Добавляем атрибуты
        inner_width = [inner_max_x - inner_min_x, 0].max
        inner_height = [inner_max_y - inner_min_y, 0].max
        cells_x = (inner_width / @grid_size).ceil
        cells_y = (inner_height / @grid_size).ceil
        width = max_x - min_x
        height = max_y - min_y

        group.set_attribute("grid", "step", @grid_size)
        group.set_attribute("grid", "margin_left", @margin_left)
        group.set_attribute("grid", "margin_right", @margin_right)
        group.set_attribute("grid", "margin_top", @margin_top)
        group.set_attribute("grid", "margin_bottom", @margin_bottom)
        group.set_attribute("grid", "width", width)
        group.set_attribute("grid", "height", height)
        group.set_attribute("grid", "min_x", min_x)
        group.set_attribute("grid", "min_y", min_y)
        group.set_attribute("grid", "max_x", max_x)
        group.set_attribute("grid", "max_y", max_y)
        group.set_attribute("grid", "inner_width", inner_width)
        group.set_attribute("grid", "inner_height", inner_height)
        group.set_attribute("grid", "cells_x", cells_x)
        group.set_attribute("grid", "cells_y", cells_y)
        group.set_attribute("grid", "plane_normal", normal.to_a)
        group.set_attribute("grid", "plane_origin", plane_origin.to_a)
        group.set_attribute("grid", "transformation", transformation.to_a)
        group.set_attribute("grid", "contour_points", contour_points_local.map { |p| p.to_a }.flatten)
        group.set_attribute("grid", "mode", "contour")

        model.commit_operation

        # Выделяем созданную сетку
        model.selection.clear
        model.selection.add(group)

        Sketchup.status_text = "Контурная сетка создана: #{group.name}"
        group
      end

      private

      def project_to_plane(point, plane_origin, normal)
        normal = Geom::Vector3d.new(normal) unless normal.is_a?(Geom::Vector3d)
        normal.normalize!

        plane_origin = Geom::Point3d.new(plane_origin) unless plane_origin.is_a?(Geom::Point3d)
        point = Geom::Point3d.new(point) unless point.is_a?(Geom::Point3d)

        vector = point - plane_origin
        distance = vector.dot(normal)

        point.offset(normal, -distance)
      end

      def point_to_local(point, transformation_inv)
        point.transform(transformation_inv)
      end

      def point_from_local(local_point, transformation)
        local_point.transform(transformation)
      end
    end
  end
end
