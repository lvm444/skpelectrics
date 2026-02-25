require 'sketchup'
require_relative 'sketchup_edge_visitor'

module Lvm444Dev
  module ElectricLine

    class LengthCalculator < SketchupVisitor::EdgeVisitor
      attr_reader :length

      def initialize
        @length = 0.0
      end

      def visit_edge(edge)
        @length += edge.length.to_m
      end
    end

  end
end
