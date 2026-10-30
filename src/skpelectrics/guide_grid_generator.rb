require 'sketchup'
require 'json'

module Lvm444Dev
  module GuideGridGenerator

    # ================================================================
    # Module State
    # ================================================================

    @dialog = nil
    @guide_group = nil         # Sketchup::Group containing all ConstructionLines
    @plane = nil               # [a,b,c,d] from Geom.fit_plane_to_points
    @basis = nil               # { origin: Point3d, u_axis: Vector3d, v_axis: Vector3d }
    @rects_2d = []             # Array of [u_min, v_min, u_max, v_max] (axis-aligned in UV)
    @rects_3d = []             # Array of [p0,p1,p2,p3] for drawing preview
    @shape_loops = nil         # Array of 3D polygon outlines (union), ordered CCW
    @tool = nil
    @tool_active = false

    # Default settings (model units — SketchUp internal inches)
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

    # Called from JS: sketchup.finish_shape()
    def self.finish_shape
      compute_shape
      regenerate_guides
      @tool.set_idle if @tool && @tool.respond_to?(:set_idle)
      if @dialog && @dialog.visible?
        @dialog.execute_script('onShapeReady()')
      end
    end

    # Called from JS: sketchup.reset_shape()
    def self.reset_shape
      clear_guides
      @rects_2d = []
      @rects_3d = []
      @shape_loops = nil
      @plane = nil
      @basis = nil
      @tool.reset if @tool && @tool.respond_to?(:reset)
      if @dialog && @dialog.visible?
        @dialog.execute_script('onShapeReset()')
      end
    end

    # Called by Tool after 3 plane points are picked
    def self.set_plane_basis(origin, u_axis, v_axis, plane)
      @basis = { origin: origin, u_axis: u_axis, v_axis: v_axis }
      @plane = plane
      @rects_2d = []
      @rects_3d = []
      @shape_loops = nil
      clear_guides
      if @dialog && @dialog.visible?
        @dialog.execute_script('onPlaneReady()')
      end
    end

    # Called by Tool when a rectangle is drawn (two diagonal points, in 3D)
    def self.add_rectangle_3d(p1, p2)
      return unless @basis

      u1 = (p1 - @basis[:origin]) % @basis[:u_axis]
      v1 = (p1 - @basis[:origin]) % @basis[:v_axis]
      u2 = (p2 - @basis[:origin]) % @basis[:u_axis]
      v2 = (p2 - @basis[:origin]) % @basis[:v_axis]

      u_min, u_max = [u1, u2].min, [u1, u2].max
      v_min, v_max = [v1, v2].min, [v1, v2].max

      @rects_2d << [u_min, v_min, u_max, v_max]
      @rects_3d << [[u_min, v_min], [u_max, v_min], [u_max, v_max], [u_min, v_max]].map do |u, v|
        to_3d(u, v)
      end

      if @dialog && @dialog.visible?
        @dialog.execute_script("onRectangleAdded(#{@rects_2d.size})")
      end
    end

    def self.basis
      @basis
    end

    def self.rects_3d
      @rects_3d
    end

    def self.shape_loops
      @shape_loops
    end

    def self.rect_vertices
      seen = {}
      result = []
      @rects_3d.each do |corners|
        corners.each do |p|
          key = [p.x.round(6), p.y.round(6), p.z.round(6)]
          unless seen[key]
            seen[key] = true
            result << p
          end
        end
      end
      result
    end

    def self.rect_edges
      edges = []
      @rects_3d.each do |corners|
        (0..3).each do |i|
          edges << [corners[i], corners[(i + 1) % 4]]
        end
      end
      edges
    end

    def self.to_3d(u, v)
      b = @basis
      Geom::Point3d.new(
        b[:origin].x + u * b[:u_axis].x + v * b[:v_axis].x,
        b[:origin].y + u * b[:u_axis].y + v * b[:v_axis].y,
        b[:origin].z + u * b[:u_axis].z + v * b[:v_axis].z
      )
    end

    def self.to_2d(point)
      b = @basis
      [(point - b[:origin]) % b[:u_axis], (point - b[:origin]) % b[:v_axis]]
    end

    # ================================================================
    # Guide Line Management
    # ================================================================

    def self.clear_guides
      return unless @guide_group
      @guide_group.erase! if @guide_group.valid?
      @guide_group = nil
    end

    def self.regenerate_guides
      return unless @shape_loops && !@shape_loops.empty?
      return if @settings[:guide_count] < 1

      model = Sketchup.active_model
      return unless model

      model.start_operation('Generate Guide Grid', true)

      clear_guides
      generate_guides

      model.commit_operation

      cline_count = @guide_group ? @guide_group.entities.count { |e| e.is_a?(Sketchup::ConstructionLine) } : 0
      if @dialog && @dialog.visible?
        @dialog.execute_script("onGuidesGenerated(#{cline_count})")
      end
    rescue => e
      model.abort_operation
      puts "GuideGridGenerator error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    end

    def self.generate_guides
      model = Sketchup.active_model
      @guide_group = model.active_entities.add_group
      @guide_group.name = 'GuideGrid'
      group_entities = @guide_group.entities

      normal = Geom::Vector3d.new(@plane[0], @plane[1], @plane[2])
      count = @settings[:guide_count]
      edge_offset = @settings[:edge_offset]
      interval = @settings[:interval]

      @shape_loops.each do |loop3d|
        (0...count).each do |i|
          distance = edge_offset + i * interval

          inner = compute_offset_polygon(loop3d, normal, distance)
          break unless inner

          # Stop when the offset polygon collapses (area <= 0 for a CCW loop)
          area = signed_area_2d(inner.map { |p| to_2d(p) })
          break if area <= 0

          n = inner.size
          (0...n).each do |j|
            group_entities.add_cline(inner[j], inner[(j + 1) % n])
          end
        end
      end
    end

    # Offset a CCW polygon inward by `distance` (mitered offset).
    # Returns array of Point3d or nil if degenerate.
    def self.compute_offset_polygon(corners_3d, plane_normal, distance)
      n = corners_3d.size
      offset_lines = (0...n).map do |i|
        p1 = corners_3d[i]
        p2 = corners_3d[(i + 1) % n]
        d = p2 - p1
        inward = (plane_normal * d).normalize  # cross(plane_normal, d) — inward for CCW
        off = Geom::Vector3d.new(inward.x * distance, inward.y * distance, inward.z * distance)
        [p1 + off, p2 + off]
      end

      corners = []
      (0...n).each do |i|
        pt = intersect_lines_2d_on_plane(offset_lines[i], offset_lines[(i + 1) % n])
        return nil unless pt
        corners << pt
      end
      corners
    end

    # Intersect two infinite lines defined by point pairs on their shared plane.
    def self.intersect_lines_2d_on_plane(line1, line2)
      p1 = line1[0]; d1 = line1[1] - line1[0]
      p2 = line2[0]; d2 = line2[1] - line2[0]

      cross = Geom::Vector3d.new(
        d1.y * d2.z - d1.z * d2.y,
        d1.z * d2.x - d1.x * d2.z,
        d1.x * d2.y - d1.y * d2.x
      )

      ax, ay = if cross.x.abs >= cross.y.abs && cross.x.abs >= cross.z.abs
                 [:y, :z]
               elsif cross.y.abs >= cross.z.abs
                 [:x, :z]
               else
                 [:x, :y]
               end

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
    # Union of axis-aligned rectangles (in UV space)
    # ================================================================

    def self.compute_shape
      loops_2d = union_rects_2d(@rects_2d)
      @shape_loops = loops_2d.map do |loop_2d|
        clean = remove_collinear_2d(make_ccw_2d(loop_2d))
        clean.map { |u, v| to_3d(u, v) }
      end
    end

    # Returns array of polygon loops (each loop is an array of [u,v] points).
    def self.union_rects_2d(rects)
      return [] if rects.empty?

      xs = []
      ys = []
      rects.each do |u1, v1, u2, v2|
        xs << u1 << u2
        ys << v1 << v2
      end
      xs = xs.uniq.sort
      ys = ys.uniq.sort
      return [] if xs.size < 2 || ys.size < 2

      width = xs.size - 1
      height = ys.size - 1
      covered = Array.new(width * height, false)

      (0...width).each do |i|
        (0...height).each do |j|
          cx = (xs[i] + xs[i + 1]) / 2.0
          cy = (ys[j] + ys[j + 1]) / 2.0
          covered[i + j * width] = rects.any? do |u1, v1, u2, v2|
            cx > u1 && cx < u2 && cy > v1 && cy < v2
          end
        end
      end

      boundary_edges = []

      (0..width).each do |i|
        (0...height).each do |j|
          left = i > 0 ? covered[(i - 1) + j * width] : false
          right = i < width ? covered[i + j * width] : false
          if left != right
            boundary_edges << [[xs[i], ys[j]], [xs[i], ys[j + 1]]]
          end
        end
      end

      (0...width).each do |i|
        (0..height).each do |j|
          bottom = j > 0 ? covered[i + (j - 1) * width] : false
          top = j < height ? covered[i + j * width] : false
          if bottom != top
            boundary_edges << [[xs[i], ys[j]], [xs[i + 1], ys[j]]]
          end
        end
      end

      stitch_edges_2d(boundary_edges)
    end

    def self.stitch_edges_2d(edges)
      adjacency = {}
      remaining = {}
      edges.each do |p1, p2|
        (adjacency[p1] ||= []) << p2
        (adjacency[p2] ||= []) << p1
        key = edge_key(p1, p2)
        remaining[key] = (remaining[key] || 0) + 1
      end

      loops = []
      edges.each do |start_p, second_p|
        key = edge_key(start_p, second_p)
        next unless remaining[key] && remaining[key] > 0

        remaining[key] -= 1
        loop_pts = [start_p, second_p]
        current = second_p

        while current != start_p
          neighbors = adjacency[current]
          next_pt = neighbors.find do |n|
            nk = edge_key(current, n)
            (remaining[nk] || 0) > 0
          end
          break unless next_pt
          nk = edge_key(current, next_pt)
          remaining[nk] -= 1
          loop_pts << next_pt
          current = next_pt
          break if current == start_p
        end

        uniq_pts = loop_pts.uniq
        loops << uniq_pts if uniq_pts.size >= 3
      end

      loops
    end

    def self.edge_key(a, b)
      (a <=> b) <= 0 ? [a, b] : [b, a]
    end

    def self.signed_area_2d(points)
      area = 0.0
      (0...points.size).each do |i|
        x1, y1 = points[i]
        x2, y2 = points[(i + 1) % points.size]
        area += x1 * y2 - x2 * y1
      end
      area / 2.0
    end

    def self.make_ccw_2d(points)
      signed_area_2d(points) < 0 ? points.reverse : points
    end

    # Remove consecutive collinear vertices so polygon offset does not
    # produce parallel "adjacent" lines on straight sections.
    def self.remove_collinear_2d(points)
      return points if points.size < 3

      result = []
      n = points.size
      (0...n).each do |i|
        p0 = points[(i - 1) % n]
        p1 = points[i]
        p2 = points[(i + 1) % n]
        d1x = p1[0] - p0[0]; d1y = p1[1] - p0[1]
        d2x = p2[0] - p1[0]; d2y = p2[1] - p1[1]
        cross = d1x * d2y - d1y * d2x
        result << p1 if cross.abs > 1.0e-9
      end
      result
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
      dialog.set_size(290, 230)
      dialog.center
      dialog
    end

    def self.attach_callbacks
      @dialog.add_action_callback('dialog_ready') do |_ctx|
        puts 'Guide Grid dialog ready'
        nil
      end

      @dialog.add_action_callback('apply_settings') do |_ctx, json_str|
        apply_settings(json_str)
        nil
      end

      @dialog.add_action_callback('finish_shape') do |_ctx|
        finish_shape
        nil
      end

      @dialog.add_action_callback('reset_shape') do |_ctx|
        reset_shape
        nil
      end
    end

    def self.activate_tool
      model = Sketchup.active_model
      return unless model

      @tool = Tool.new
      model.select_tool(@tool)
      @tool_active = true
    end

    def self.deactivate
      @tool_active = false
      clear_guides
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
        @rect_p1 = nil            # First corner of the rectangle being drawn
        @mouse_pos = nil          # Current mouse position projected on plane
        @snapped = false          # Whether the cursor is snapped
        @snap_tooltip = nil       # Tooltip text of the current snap
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
          # Ignore clicks — shape is finalized
        end
        update_status
        view.invalidate
      end

      def onMouseMove(flags, x, y, view)
        if @state == :drawing_rect
          pt = plane_point(x, y, view)
          @mouse_pos = pt if pt
          if @snapped
            view.tooltip = @snap_tooltip || 'Привязка к точке/грани'
          else
            view.tooltip = nil
          end
        else
          @ip.pick(view, x, y)
          view.tooltip = @ip.tooltip if @ip.valid?
        end
        view.invalidate
      end

      def draw(view)
        draw_plane_points(view)
        draw_plane_preview(view)
        draw_cursor_marker(view)
        draw_rect_preview(view)
        draw_rects(view)
        draw_shape(view)
        @ip.draw(view) if @ip.display? && @state == :picking_plane
      end

      def getExtents
        bb = Geom::BoundingBox.new
        @plane_pts.each { |pt| bb.add(pt) }
        bb.add(@rect_p1) if @rect_p1
        bb.add(@mouse_pos) if @mouse_pos
        (GuideGridGenerator.rects_3d || []).each { |c| c.each { |p| bb.add(p) } }
        (GuideGridGenerator.shape_loops || []).each { |c| c.each { |p| bb.add(p) } }
        bb.valid? ? bb : Sketchup.active_model.bounds
      end

      def onSetCursor
        UI.set_cursor(CURSOR_PENCIL)
      end

      def enableVCB?
        false
      end

      # ---- Public state transitions ----

      def set_idle
        @state = :idle
        @rect_p1 = nil
        @mouse_pos = nil
        update_status
        Sketchup.active_model.active_view.invalidate
      end

      def reset
        @state = :picking_plane
        @plane_pts = []
        @plane = nil
        @rect_p1 = nil
        @mouse_pos = nil
        update_status
        Sketchup.active_model.active_view.invalidate
      end

      # ---- Tool Helpers ----

      private

      def pick_plane_point(x, y, view)
        @ip.pick(view, x, y)
        return unless @ip.valid?

        @plane_pts << @ip.position

        if @plane_pts.size >= 3
          finalize_plane
          @plane_pts.clear unless @plane
        end
      end

      def finalize_plane
        @plane = Geom.fit_plane_to_points(@plane_pts)
        return false unless @plane

        origin = @plane_pts[0]
        u_axis = (@plane_pts[1] - origin).normalize
        normal = Geom::Vector3d.new(@plane[0], @plane[1], @plane[2])
        v_axis = (normal * u_axis).normalize

        GuideGridGenerator.set_plane_basis(origin, u_axis, v_axis, @plane)
        @state = :drawing_rect
        @rect_p1 = nil
        @mouse_pos = nil
        true
      rescue
        @plane = nil
        false
      end

      def pick_rect_point(x, y, view)
        pt = plane_point(x, y, view)
        return unless pt

        if @rect_p1.nil?
          @rect_p1 = pt
        else
          GuideGridGenerator.add_rectangle_3d(@rect_p1, pt)
          @rect_p1 = nil
          @mouse_pos = nil
        end
      end

      # Project the mouse ray onto the working plane, snapping to model
      # geometry (projected onto the plane), the 3 plane points, and existing
      # rectangle vertices/edges.
      def plane_point(x, y, view)
        return nil unless @plane

        ray = view.pickray(x, y)
        raw = Geom.intersect_line_plane([ray[0], ray[1]], @plane)
        return nil unless raw

        threshold = view.pixels_to_model(15, raw)
        candidates = []
        @snap_tooltip = nil

        # Model inference (edges/vertices), projected onto the plane
        @ip.pick(view, x, y)
        if @ip.valid? && @ip.position
          proj = project_point_to_plane(@ip.position)
          d = proj.distance(raw)
          if d < threshold
            candidates << [d, proj]
            @snap_tooltip = @ip.tooltip
          end
        end

        # The 3 picked plane points
        @plane_pts.each do |p|
          d = p.distance(raw)
          candidates << [d, p] if d < threshold
        end

        # Existing rectangle vertices
        GuideGridGenerator.rect_vertices.each do |v|
          d = v.distance(raw)
          candidates << [d, v] if d < threshold
        end

        # Existing rectangle edges
        GuideGridGenerator.rect_edges.each do |p1, p2|
          proj = project_point_to_segment(raw, p1, p2)
          d = proj.distance(raw)
          candidates << [d, proj] if d < threshold
        end

        @snapped = !candidates.empty?
        return raw if candidates.empty?
        candidates.min_by { |d, _| d }[1]
      end

      # Orthogonal projection of a point onto the working plane [a,b,c,d].
      def project_point_to_plane(pt)
        a, b, c, d = @plane
        nlen2 = a * a + b * b + c * c
        return pt if nlen2 < 1.0e-12
        dot = a * pt.x + b * pt.y + c * pt.z + d
        Geom::Point3d.new(
          pt.x - (dot / nlen2) * a,
          pt.y - (dot / nlen2) * b,
          pt.z - (dot / nlen2) * c
        )
      end

      def project_point_to_segment(pt, p1, p2)
        d = p2 - p1
        len2 = d % d
        return p1 if len2 < 1.0e-12
        t = ((pt - p1) % d) / len2
        t = [[t, 0.0].max, 1.0].min
        Geom::Point3d.new(p1.x + t * d.x, p1.y + t * d.y, p1.z + t * d.z)
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
          Sketchup.status_text = 'Форма задана. Меняйте настройки в окне диалога'
        end
      end

      # ---- Drawing Methods ----

      def draw_plane_points(view)
        @plane_pts.each { |pt| draw_cross(view, pt, 10) }

        if @plane_pts.size >= 2
          view.line_width = 2
          view.drawing_color = Sketchup::Color.new(0, 128, 255)
          (0...@plane_pts.size - 1).each do |i|
            view.draw_line(@plane_pts[i], @plane_pts[i + 1])
          end
        end

        if @plane_pts.size >= 3
          view.line_width = 1
          view.drawing_color = Sketchup::Color.new(0, 128, 255, 64)
          view.draw(GL_TRIANGLES, @plane_pts[0..2])
          view.draw_line(@plane_pts[2], @plane_pts[0])
        end
      end

      def draw_plane_preview(view)
        return unless @state == :picking_plane && @plane_pts.size == 2 && @ip.valid?
        view.line_width = 2
        view.drawing_color = Sketchup::Color.new(128, 128, 128)
        view.draw_line(@plane_pts.last, @ip.position)
      end

      # Marker at the current snap/projected point while picking the first
      # rectangle corner (before the rubber-band rectangle appears).
      def draw_cursor_marker(view)
        return unless @state == :drawing_rect && @mouse_pos && @rect_p1.nil?
        view.line_width = 2
        view.drawing_color = Sketchup::Color.new(255, 128, 0)
        draw_cross(view, @mouse_pos, 10)
      end

      def draw_rect_preview(view)
        return unless @state == :drawing_rect && @rect_p1 && @mouse_pos
        pts = compute_preview_corners
        return if pts.empty?
        view.line_width = 2
        view.drawing_color = Sketchup::Color.new(255, 128, 0)
        view.draw(GL_LINE_LOOP, pts)
      end

      def draw_rects(view)
        rects = GuideGridGenerator.rects_3d
        return if rects.nil? || rects.empty?
        view.line_width = 2
        view.drawing_color = Sketchup::Color.new(0, 128, 255)
        rects.each { |c| view.draw(GL_LINE_LOOP, c) }
      end

      def draw_shape(view)
        loops = GuideGridGenerator.shape_loops
        return if loops.nil? || loops.empty?
        view.line_width = 3
        view.drawing_color = Sketchup::Color.new(255, 128, 0)
        loops.each { |c| view.draw(GL_LINE_LOOP, c) }
      end

      def compute_preview_corners
        basis = GuideGridGenerator.basis
        return [] unless @rect_p1 && @mouse_pos && basis

        u1 = (@rect_p1 - basis[:origin]) % basis[:u_axis]
        v1 = (@rect_p1 - basis[:origin]) % basis[:v_axis]
        u2 = (@mouse_pos - basis[:origin]) % basis[:u_axis]
        v2 = (@mouse_pos - basis[:origin]) % basis[:v_axis]

        [[u1, v1], [u2, v1], [u2, v2], [u1, v2]].map { |u, v| GuideGridGenerator.to_3d(u, v) }
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
