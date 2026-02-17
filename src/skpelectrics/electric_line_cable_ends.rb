require 'sketchup'
require_relative 'sketchup_vertex_visitor'

module Lvm444Dev
  module ElectricLine

    class CableEnds < SketchupVisitor::VertextVisitor
      attr_reader :ends

      def initialize
        @ends = []
      end

      def visit_vertex(vertex)
        @ends << vertex if is_cable_end?(vertex)
      end

      private
      # @param vertex [Sketchup::Vertex] вершина
      def is_cable_end?(vertex)
        vertex.edges.size == 1
      end
    end

  end
end
