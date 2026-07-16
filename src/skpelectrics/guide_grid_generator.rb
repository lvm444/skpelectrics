require 'sketchup'

module Lvm444Dev
  module GuideGridGenerator

    # ================================================================
    # Module State
    # ================================================================

    @dialog = nil
    @guide_clines = []         # Array of created ConstructionLine entities
    @rectangle = nil           # { corners: [p0,p1,p2,p3], plane: [a,b,c,d] }
    @tool_active = false

    # Default settings (in model units — SketchUp internal inches)
    @settings = {
      guide_count: 3,
      edge_offset: 100.mm,
      interval: 200.mm
    }

    # ================================================================
    # Public API
    # ================================================================

    # Called from main.rb menu command
    def self.show_dialog
      if @dialog && @dialog.visible?
        @dialog.bring_to_front
      else
        @dialog = create_dialog
        attach_callbacks
        @dialog.show
      end
      activate_tool
    end

    # Called from JS: sketchup.apply_settings(json)
    def self.apply_settings(json_str)
      data = JSON.parse(json_str)
      @settings[:guide_count] = data['guideCount'].to_i
      @settings[:edge_offset] = data['edgeOffset'].to_f.mm
      @settings[:interval] = data['interval'].to_f.mm
      regenerate_guides
    end

    # Called by Tool when rectangle is defined
    def self.set_rectangle(corners, plane)
      @rectangle = { corners: corners, plane: plane }
      # Notify JS dialog that rectangle is ready
      if @dialog && @dialog.visible?
        @dialog.execute_script('onRectangleReady()')
      end
      regenerate_guides
    end

    # ================================================================
    # Guide Line Management
    # ================================================================

    def self.clear_guides
      model = Sketchup.active_model
      return unless model

      entities = model.active_entities
      @guide_clines.each do |cline|
        next unless cline.valid?
        entities.erase_entities(cline)
      end
      @guide_clines.clear
    end

    def self.regenerate_guides
      return unless @rectangle
      return if @settings[:guide_count] < 1

      model = Sketchup.active_model
      return unless model

      model.start_operation('Generate Guide Grid', true)

      clear_guides
      generate_guides

      model.commit_operation

      # Notify dialog
      if @dialog && @dialog.visible?
        @dialog.execute_script("onGuidesGenerated(#{@guide_clines.size})")
      end
    rescue => e
      model.abort_operation
      puts "GuideGridGenerator error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    end

    def self.generate_guides
      corners = @rectangle[:corners]
      plane = @rectangle[:plane]
      normal = plane[0..2]
      count = @settings[:guide_count]
      edge_offset = @settings[:edge_offset]
      interval = @settings[:interval]

      entities = Sketchup.active_model.active_entities

      # Compute rectangle centroid (for inward direction check)
      centroid = Geom::Point3d.new(
        corners.map(&:x).sum / 4.0,
        corners.map(&:y).sum / 4.0,
        corners.map(&:z).sum / 4.0
      )

      # Pre-compute edges: each edge is [p_start, p_end, inward_normal]
      edges = compute_edges_with_normals(corners, normal, centroid)

      (0...count).each do |i|
        distance = edge_offset + i * interval

        # Compute offset corners for this inner rectangle
        inner_corners = compute_inner_rectangle(edges, distance)

        # Skip if rectangle collapsed
        next unless inner_corners

        # Create 4 construction lines (one per edge)
        (0..3).each do |j|
          p1 = inner_corners[j]
          p2 = inner_corners[(j + 1) % 4]
          cline = entities.add_cline(p1, p2)
          @guide_clines << cline
        end
      end
    end

    # Compute edge segments with inward normals
    # Returns array of [start_pt, end_pt, inward_normal_vector]
    def self.compute_edges_with_normals(corners, plane_normal, centroid)
      edges = []
      (0..3).each do |i|
        p1 = corners[i]
        p2 = corners[(i + 1) % 4]
        edge_dir = p2 - p1
        # Normal to edge, lying in the plane
        edge_normal = (edge_dir * plane_normal).normalize
        # Ensure normal points inward (toward centroid)
        mid = Geom::Point3d.new(
          (p1.x + p2.x) / 2.0,
          (p1.y + p2.y) / 2.0,
          (p1.z + p2.z) / 2.0
        )
        to_centroid = centroid - mid
        if edge_normal % to_centroid < 0
          edge_normal = edge_normal.reverse
        end
        edges << [p1, p2, edge_normal]
      end
      edges
    end

    # Compute inner rectangle corners by offsetting each edge inward
    # Returns array of 4 Point3d or nil if rectangle is degenerate
    def self.compute_inner_rectangle(edges, distance)
      # Offset each edge: line defined by p1,p2 + normal*distance
      offset_lines = edges.map do |p1, p2, normal|
        offset_vec = Geom::Vector3d.new(
          normal.x * distance,
          normal.y * distance,
          normal.z * distance
        )
        [p1 + offset_vec, p2 + offset_vec]
      end

      # Intersect adjacent offset lines to get new corners
      corners = []
      (0..3).each do |i|
        line1 = offset_lines[i]
        line2 = offset_lines[(i + 1) % 4]
        intersection = intersect_lines_2d_on_plane(line1, line2)
        return nil unless intersection
        corners << intersection
      end
      corners
    end

    # Intersect two infinite lines defined by point pairs on their shared plane.
    # Projects to 2D using the plane normal to pick the best coordinate axes.
    def self.intersect_lines_2d_on_plane(line1, line2)
      p1 = line1[0]; d1 = line1[1] - line1[0]
      p2 = line2[0]; d2 = line2[1] - line2[0]

      # Pick two coordinates to project onto, avoiding degenerate projection.
      # Use the two axes where the cross product d1×d2 has largest components.
      cross = Geom::Vector3d.new(
        d1.y * d2.z - d1.z * d2.y,
        d1.z * d2.x - d1.x * d2.z,
        d1.x * d2.y - d1.y * d2.x
      )

      ax, ay = if cross.x.abs >= cross.y.abs && cross.x.abs >= cross.z.abs
                 [:y, :z]   # Drop X — cross is largest in X, lines span YZ well
               elsif cross.y.abs >= cross.z.abs
                 [:x, :z]   # Drop Y
               else
                 [:x, :y]   # Drop Z
               end

      # Build 2x2 linear system
      a11 = d1.send(ax); a12 = -d2.send(ax)
      a21 = d1.send(ay); a22 = -d2.send(ay)
      b1 = (p2 - p1).send(ax)
      b2 = (p2 - p1).send(ay)

      det = a11 * a22 - a12 * a21
      return nil if det.abs < 1.0e-9

      t = (b1 * a22 - b2 * a12) / det

      Geom::Point3d.new(
        p1.x + t * d1.x,
        p1.y + t * d1.y,
        p1.z + t * d1.z
      )
    end

    # ================================================================
    # Dialog Management
    # ================================================================

    def self.create_dialog
      html_file = File.join(__dir__, 'html', 'dialog_guide_grid.html')
      options = {
        dialog_title: 'Сетка направляющих',
        preferences_key: 'Lvm444Dev.GuideGridGenerator',
        style: UI::HtmlDialog::STYLE_DIALOG
      }
      dialog = UI::HtmlDialog.new(options)
      dialog.set_file(html_file)
      dialog.center
      dialog
    end

    def self.attach_callbacks
      @dialog.add_action_callback('dialog_ready') do |_ctx|
        # Dialog is loaded and ready
        puts 'Guide Grid dialog ready'
        nil
      end

      @dialog.add_action_callback('apply_settings') do |_ctx, json_str|
        apply_settings(json_str)
        nil
      end
    end

    def self.activate_tool
      model = Sketchup.active_model
      return unless model

      tool = Tool.new
      model.select_tool(tool)
      @tool_active = true
    end

    def self.deactivate
      @tool_active = false
      clear_guides
      @rectangle = nil
      if @dialog
        @dialog.close
        @dialog = nil
      end
    end

    # ================================================================
    # Custom SketchUp Tool
    # ================================================================

    class Tool
      CURSOR_PENCIL = 632

      def initialize
        @state = :picking_plane   # :picking_plane | :drawing_rect | :idle
        @plane_pts = []           # 3 points defining the plane
        @plane = nil              # [a, b, c, d]
        @rect_p1 = nil            # First corner of rectangle
        @mouse_pos = nil          # Current mouse position on plane (for preview)
        @ip = Sketchup::InputPoint.new
      end

      # ---- SketchUp Tool Interface ----

      def activate
        update_status
      end

      def deactivate(view)
        view.invalidate
      end

      def resume(view)
        update_status
        view.invalidate
      end

      def suspend(view)
        view.invalidate
      end

      def onLButtonDown(flags, x, y, view)
        case @state
        when :picking_plane
          pick_plane_point(x, y, view)
        when :drawing_rect
          pick_rect_point(x, y, view)
        when :idle
          # Clicking again restarts the process
          reset_tool
          pick_plane_point(x, y, view)
        end
        update_status
        view.invalidate
      end

      def onMouseMove(flags, x, y, view)
        @ip.pick(view, x, y)

        if @state == :drawing_rect && @rect_p1 && @plane
          # Project mouse onto plane for rubber-band preview
          ray = view.pickray(x, y)
          pt = Geom.intersect_line_plane([ray[0], ray[1]], @plane)
          @mouse_pos = pt if pt
        end

        view.tooltip = @ip.tooltip if @ip.valid?
        view.invalidate
      end

      def draw(view)
        draw_plane_points(view)
        draw_plane_preview(view)
        draw_rectangle_preview(view)
        draw_rectangle(view)
        @ip.draw(view) if @ip.display?
      end

      def getExtents
        bounds = Sketchup.active_model.bounds
        # Expand to include our points
        bb = Geom::BoundingBox.new
        @plane_pts.each { |pt| bb.add(pt) }
        bb.add(@rect_p1) if @rect_p1
        bb.add(@mouse_pos) if @mouse_pos
        bb.valid? ? bb : bounds
      end

      def onSetCursor
        UI.set_cursor(CURSOR_PENCIL)
      end

      def enableVCB?
        false
      end

      # ---- Tool Helpers ----

      private

      def pick_plane_point(x, y, view)
        @ip.pick(view, x, y)
        return unless @ip.valid?

        @plane_pts << @ip.position
        puts "Plane point #{@plane_pts.size}: #{@ip.position}"

        if @plane_pts.size >= 3
          compute_plane
          if @plane
            @state = :drawing_rect
            @rect_p1 = nil
            @mouse_pos = nil
            GuideGridGenerator.instance_variable_set(:@guide_clines, [])
            GuideGridGenerator.instance_variable_set(:@rectangle, nil)
            puts "Plane computed, ready for rectangle drawing"
          else
            # Points collinear — reset
            puts "Points are collinear, resetting"
            @plane_pts.clear
          end
        end
      end

      def pick_rect_point(x, y, view)
        @ip.pick(view, x, y)
        pt = @ip.valid? ? @ip.position : project_to_plane(x, y, view)
        return unless pt

        if @rect_p1.nil?
          @rect_p1 = pt
          puts "Rectangle corner 1: #{pt}"
        else
          rect_p2 = pt
          puts "Rectangle corner 2: #{rect_p2}"
          compute_rectangle(@rect_p1, rect_p2)
          @state = :idle
        end
      end

      def project_to_plane(x, y, view)
        return nil unless @plane
        ray = view.pickray(x, y)
        Geom.intersect_line_plane([ray[0], ray[1]], @plane)
      end

      def compute_plane
        @plane = Geom.fit_plane_to_points(@plane_pts)
      rescue
        @plane = nil
      end

      def compute_rectangle(p1, p2)
        # Compute 4 corners of axis-aligned rectangle on the plane
        # Project into 2D on the plane, compute rectangle, project back

        # Define local coordinate system on the plane
        origin = @plane_pts[0]
        u_axis = (@plane_pts[1] - origin).normalize
        normal = Geom::Vector3d.new(@plane[0], @plane[1], @plane[2])
        v_axis = (normal * u_axis).normalize

        # Convert p1, p2 to local 2D
        u1 = (p1 - origin) % u_axis
        v1 = (p1 - origin) % v_axis
        u2 = (p2 - origin) % u_axis
        v2 = (p2 - origin) % v_axis

        # 4 corners in 2D
        uv_corners = [
          [u1, v1],
          [u2, v1],
          [u2, v2],
          [u1, v2]
        ]

        # Convert back to 3D
        corners_3d = uv_corners.map do |u, v|
          Geom::Point3d.new(
            origin.x + u * u_axis.x + v * v_axis.x,
            origin.y + u * u_axis.y + v * v_axis.y,
            origin.z + u * u_axis.z + v * v_axis.z
          )
        end

        GuideGridGenerator.set_rectangle(corners_3d, @plane)
      end

      def reset_tool
        @state = :picking_plane
        @plane_pts.clear
        @plane = nil
        @rect_p1 = nil
        @mouse_pos = nil
      end

      def update_status
        case @state
        when :picking_plane
          remaining = 3 - @plane_pts.size
          Sketchup.status_text = "Выберите #{remaining} точк#{remaining == 1 ? 'у' : 'и'} для задания плоскости"
        when :drawing_rect
          if @rect_p1.nil?
            Sketchup.status_text = 'Выберите первый угол прямоугольника'
          else
            Sketchup.status_text = 'Выберите второй угол прямоугольника'
          end
        when :idle
          Sketchup.status_text = 'Прямоугольник задан. Меняйте настройки в окне диалога'
        end
      end

      # ---- Drawing Methods ----

      def draw_plane_points(view)
        @plane_pts.each do |pt|
          draw_cross(view, pt, 10)
        end

        # Draw lines between plane points
        if @plane_pts.size >= 2
          view.line_width = 2
          view.drawing_color = Sketchup::Color.new(0, 128, 255)
          (0...@plane_pts.size - 1).each do |i|
            view.draw_line(@plane_pts[i], @plane_pts[i + 1])
          end
        end

        # Draw triangle of the plane
        if @plane_pts.size >= 3
          view.line_width = 1
          view.drawing_color = Sketchup::Color.new(0, 128, 255, 64)
          view.draw(GL_TRIANGLES, @plane_pts[0..2])
          view.draw_line(@plane_pts[2], @plane_pts[0])
        end
      end

      def draw_plane_preview(view)
        # Preview the third point position
        return unless @state == :picking_plane && @plane_pts.size == 2 && @ip.valid?
        view.line_width = 2
        view.drawing_color = Sketchup::Color.new(128, 128, 128)
        view.draw_line(@plane_pts.last, @ip.position)
      end

      def draw_rectangle_preview(view)
        return unless @state == :drawing_rect && @rect_p1 && @mouse_pos
        pts = compute_preview_corners
        return if pts.empty?
        view.line_width = 2
        view.drawing_color = Sketchup::Color.new(255, 128, 0)
        view.draw(GL_LINE_LOOP, pts)
      end

      def draw_rectangle(view)
        return unless GuideGridGenerator.instance_variable_get(:@rectangle)
        rect = GuideGridGenerator.instance_variable_get(:@rectangle)
        corners = rect[:corners]
        view.line_width = 3
        view.drawing_color = Sketchup::Color.new(255, 200, 0, 128)
        view.draw(GL_LINE_LOOP, corners)
        view.draw(GL_QUADS, corners)
      end

      def compute_preview_corners
        return [] unless @rect_p1 && @mouse_pos && @plane && @plane_pts.size >= 3

        origin = @plane_pts[0]
        u_axis = (@plane_pts[1] - origin).normalize
        normal = Geom::Vector3d.new(@plane[0], @plane[1], @plane[2])
        v_axis = (normal * u_axis).normalize

        u1 = (@rect_p1 - origin) % u_axis
        v1 = (@rect_p1 - origin) % v_axis
        u2 = (@mouse_pos - origin) % u_axis
        v2 = (@mouse_pos - origin) % v_axis

        [
          [u1, v1], [u2, v1], [u2, v2], [u1, v2]
        ].map do |u, v|
          Geom::Point3d.new(
            origin.x + u * u_axis.x + v * v_axis.x,
            origin.y + u * u_axis.y + v * v_axis.y,
            origin.z + u * u_axis.z + v * v_axis.z
          )
        end
      end

      def draw_cross(view, point, size)
        view.line_width = 3
        view.drawing_color = 'red'
        half = size / 2.0
        view.draw_line(
          [point.x - half, point.y, point.z],
          [point.x + half, point.y, point.z]
        )
        view.draw_line(
          [point.x, point.y - half, point.z],
          [point.x, point.y + half, point.z]
        )
      end
    end

  end
end
