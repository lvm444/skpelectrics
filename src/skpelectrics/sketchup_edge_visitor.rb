require 'sketchup'

module Lvm444Dev
  module SketchupVisitor

    class EdgeVisitor
      def visit(entity)
        case entity
          when Sketchup::Group
            visit_group(entity)
          when Sketchup::Edge
            visit_edge(entity)
          else
            visit_other(entity)
        end
      end

      def visit_group(group)
        group.entities.each { |e| visit(e) }
      end

      # @param edge [Sketchup::Edge] линия
      def visit_edge(edge)
      end

      def visit_other(entity)
      end
    end

  end
end
