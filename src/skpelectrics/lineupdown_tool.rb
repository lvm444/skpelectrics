require 'sketchup'

module Lvm444Dev
  module LineupdownTool
    DEFAULT_TARGET_HEIGHT = 3000.mm
     # Here we have hard coded a special ID for the pencil cursor in SketchUp.
    CURSOR_PENCIL = 632

    def self.activate
      model = Sketchup.active_model
      if model
        tool = Tool.new
        model.select_tool(tool)
      end
    end

    class Tool
      def activate
        @mouse_ip = Sketchup::InputPoint.new
      end

      def deactivate(view)
        view.invalidate
      end

      def onLButtonDown(flags, x, y, view)
        @mouse_ip.pick(view, x, y)
        return unless @mouse_ip.valid?

        point = @mouse_ip.position
        end_point = Geom::Point3d.new(point.x, point.y, DEFAULT_TARGET_HEIGHT)

        entities = Sketchup.active_model.active_entities
        entities.add_line(point, end_point)
        view.invalidate
      end

      def onMouseMove(flags, x, y, view)
        @mouse_ip.pick(view, x, y)
        view.tooltip = @mouse_ip.tooltip if @mouse_ip.valid?
        view.invalidate
      end

      def draw(view)
        @mouse_ip.draw(view) if @mouse_ip.display?
      end

      def resume(view)
        view.invalidate
      end

      def suspend(view)
        view.invalidate
      end

      def onSetCursor
        UI.set_cursor(CURSOR_PENCIL)
      end
    end

  end
end
