require 'sketchup'
require_relative 'sketchup_edge_visitor'

module Lvm444Dev
  module SketchupVisitor

    class VertextVisitor < SketchupVisitor::EdgeVisitor
      def visit(entity)
        if entity.is_a?(Sketchup::Vertex)
          visit_vertex(entity)
        else
          super
        end
      end

      def visit_edge(edge)
        edge.vertices.each { |e| visit(e) }
      end

      # @param vertex [Sketchup::Vertex] вершина
      def visit_vertex(vertex)
      end
    end

  end
end
