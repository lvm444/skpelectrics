require 'sketchup'
require_relative 'sketchup_vertex_visitor'

module Lvm444Dev
  module ElectricLine

    class CableEnds < SketchupVisitor::VertextVisitor
      def initialize(tolerance = 0.001.mm)
        @tolerance = tolerance
        @transform = Geom::Transformation.new

        # @type [Hash<Geom::Point3d, Array<Sketchup::Vertex>>] вершины по округлённым точкам
        @point_to_vertexes = Hash.new { |hash, key| hash[key] = [] }
      end

      def ends
        @point_to_vertexes.values
          .filter { |vertexes| vertexes.size == 1 }
          .map { |vertexes| vertexes[0] }
      end

      # @param group [Sketchup::Group] линия
      def visit_group(group)
        transform_before = @transform
        @transform = @transform * group.transformation
        super
        @transform = transform_before
      end

      def visit_vertex(vertex)
        return if vertex.edges.size != 1

        position = vertex.position.transform(@transform)
        point_key = rounded_point(position)
        @point_to_vertexes[point_key] << vertex
      end

      private
      # @param point [Geom::Point3d] точка
      # @return [Geom::Point3d] "округлённая" точка
      def rounded_point(point)
        [
          (point.x / @tolerance).round * @tolerance,
          (point.y / @tolerance).round * @tolerance,
          (point.z / @tolerance).round * @tolerance
        ]
      end
    end

  end
end
