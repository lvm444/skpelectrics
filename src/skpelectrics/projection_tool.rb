module Lvm444Dev
  require 'base64'

  # Сериализует группу или компонент в строку
  def self.serialize_entity(entity)
    return nil unless entity.is_a?(Sketchup::ComponentInstance) || entity.is_a?(Sketchup::Group)

    temp_path = File.join(Sketchup.temp_dir, "temp_export.skp")
    definition = entity.definition

    # Экспортируем компонент во временный файл
    definition.save_as(temp_path)
    binary_data = File.binread(temp_path)
    File.delete(temp_path) rescue nil

    Base64.strict_encode64(binary_data)
  end

  # Десериализует строку обратно в компонент
  def self.deserialize_entity(base64_str)
    return nil unless base64_str

    binary_data = Base64.strict_decode64(base64_str)
    temp_path = File.join(Sketchup.temp_dir, "temp_import.skp")

    File.binwrite(temp_path, binary_data)
    #loaded_components = Sketchup.active_model.import(temp_path)
    defenition = Sketchup.active_model.definitions.load(temp_path)
    puts " defenition #{defenition}"
    File.delete(temp_path) rescue nil

    defenition
  end

  # Сохраняет примитив в атрибуты модели
  def self.save_primitive_to_model
    model = Sketchup.active_model
    selection = model.selection.first

    if !selection || !(selection.is_a?(Sketchup::Group) || selection.is_a?(Sketchup::ComponentInstance))
      UI.messagebox("Выберите группу или компонент!")
      return
    end

    serialized = serialize_entity(selection)
    model.set_attribute("StoredPrimitive", "data", serialized)
    UI.messagebox("Примитив сохранён в модели!")
  end

  ORIGIN = Geom::Point3d.new(0, 0, 0)

  # Безопасная нормализация вектора с обработкой нулевого вектора
  def self.safe_normalize(vector)
    if vector.length > 1e-6
      vector.normalize
    else
      # Возвращаем вектор по умолчанию (ось X) при нулевом векторе
      Geom::Vector3d.new(1, 0, 0)
    end
  end

  def self.rotation_between_vectors(from_vec, to_vec)
    begin
      from = safe_normalize(from_vec)
      to = safe_normalize(to_vec)

      # Вычисляем ось вращения
      axis = from * to

      # Если векторы коллинеарны
      if axis.length < 1e-6
        if from.dot(to) > 0.999999
          # Совпадают — нет вращения
          return Geom::Transformation.new
        else
          # Противоположны — выбираем произвольную ось, перпендикулярную from
          ortho = if (from.x.abs < 0.6)
                    Geom::Vector3d.new(1, 0, 0)
                  else
                    Geom::Vector3d.new(0, 1, 0)
                  end
          axis = from * ortho
          return Geom::Transformation.rotation(ORIGIN, safe_normalize(axis), Math::PI)
        end
      end

      # Обычное вращение
      dot = from.dot(to).clamp(-1.0, 1.0)
      angle = Math.acos(dot)
      Geom::Transformation.rotation(ORIGIN, safe_normalize(axis), angle)
    rescue => e
      puts "Rotation error: #{e.message}"
      Geom::Transformation.new
    end
  end

  def self.paste_with_orientation(target_point = nil, direction = [1, 0, 0])
    model = Sketchup.active_model

    begin
      serialized = model.get_attribute("StoredPrimitive", "data")
      unless serialized
        UI.messagebox("Нет сохраненного компонента!")
        return nil
      end

      target_point ||= begin
        UI.messagebox("Укажите точку вставки")
        ip = Sketchup::InputPoint.new
        return nil unless ip.wait_for_input
        ip.position
      end

      definition = deserialize_entity(serialized)
      unless definition
        UI.messagebox("Ошибка загрузки компонента!")
        return nil
      end

      dir_vector = Geom::Vector3d.new(direction)
      dir_vector = Geom::Vector3d.new(1, 0, 0) if dir_vector.length < 1e-6

      # Ось, которую хотим направить (например, если "вперёд" — это ось Y)
      local_forward = Geom::Vector3d.new(0, 1, 0)
      rotation = rotation_between_vectors(local_forward, dir_vector)

      # Центр компонента в его локальных координатах
      center = definition.bounds.center

      # Смещение: переместить центр в (0,0,0) перед вращением
      center_offset = Geom::Transformation.translation(center.vector_to(ORIGIN))

      # Вся трансформация: сначала центрируем, потом поворачиваем, потом переносим в целевую точку
      to_target = Geom::Transformation.translation(target_point)
      final_transform = to_target * rotation * center_offset

      # Вставка
      model.start_operation("Вставка с ориентацией", true)
      instance = model.active_entities.add_instance(definition, final_transform)

      ins_bounds = instance.bounds

      # 1. Получаем готовый вектор смещения (уже с учетом расстояния)
      # 1. Создаем копию вектора направления
      offset_vector = Geom::Vector3d.new(dir_vector.x, dir_vector.y, dir_vector.z)

      # 2. Устанавливаем длину через метод length=
      offset_vector.length = (ins_bounds.height.to_l.to_f/2)  # Явное задание длины в дюймах

      # 2. Создаем и применяем трансформацию
      transform = Geom::Transformation.translation(offset_vector)
      instance.transform!(transform)

      instance
    rescue => e
      model.abort_operation if model.respond_to?(:abort_operation)
      puts "Ошибка: #{e.message}"
      puts "stack: #{e.backtrace.join("\n\t")}"
      UI.messagebox("Ошибка: #{e.message}")
      nil
    end
  end

  # Конвертация смещения в числовое значение
  def self.convert_offset(offset)
    begin
      # Если offset уже числовой (без единиц)
      return offset.to_f if offset.is_a?(Numeric)

      # Если offset с единицами измерения (500.mm)
      return offset.to_l.to_f if offset.respond_to?(:to_l)

      # Если строка (например "500" или "500mm")
      if offset.is_a?(String)
        return offset.to_f if offset.match?(/^\d+\.?\d*$/)
        return offset.gsub(/[^\d\.]/, '').to_f
      end

      0.0 # Значение по умолчанию
    rescue => e
      puts "Ошибка конвертации смещения: #{e.message}"
      puts "Стек вызовов:\n#{e.backtrace.join("\n")}"
      0.0
    end
  end

  # Безопасное вычисление вектора смещения
  def self.calculate_offset_vector(dir_vector, offset)
    begin
      # Конвертируем смещение в число
      offset_value = convert_offset(offset)

      # Умножаем нормализованный вектор на число (без единиц измерения)
      dir_vector.normalize * offset_value
    rescue => e
      puts "Ошибка расчета вектора смещения: #{e.message}"
      puts "Стек вызовов:\n#{e.backtrace.join("\n")}"
      Geom::Vector3d.new(0, 0, 0) # Нулевой вектор при ошибке
    end
  end

  # Вставляет примитив так, чтобы его центр был в точке `target_point`
  def self.paste_primitive_at_point(target_point = nil)
    model = Sketchup.active_model
    serialized = model.get_attribute("StoredPrimitive", "data")

    if serialized.nil?
      UI.messagebox("Нет сохранённого примитива!")
      return
    end

    # Если точка не задана, запрашиваем у пользователя
    unless target_point
      picks = Sketchup::InputPoint.new
      UI.messagebox("Укажите точку вставки (кликните ЛКМ)")
      status = picks.wait_for_input
      return unless status

      target_point = picks.position
    end

    definition = deserialize_entity(serialized)
    puts "input definition #{definition}"
    if definition
      # Вычисляем центр ограничивающего прямоугольника (bounding box)
      bounds = definition.bounds
      center_offset = bounds.center

      # Создаём отрицательное смещение (корректный способ)
      negative_offset = Geom::Point3d.new(-center_offset.x, -center_offset.y, -center_offset.z)

      # Создаём трансформацию
      transform = Geom::Transformation.new(negative_offset) * Geom::Transformation.new(target_point)

      model.active_entities.add_instance(definition, transform)
      UI.messagebox("Примитив вставлен в указанную точку!")
    else
      UI.messagebox("Ошибка при вставке!")
    end
  end

  def self.find_input_objects
    puts "check_selected"
    model = Sketchup.active_model
    selection = model.selection
    selection.each do |entity|
      puts "> #{entity}"
    end

    component = selection.find {|e| e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)}
    puts "component #{component}"

    if !component
      UI.messagebox("Пожалуйста выберите: Компонент/Группу")
      return
    end


    faceGroup = selection.find { |e| e.is_a?(Sketchup::Group) }

    if faceGroup
      faceGroup = selection.find { |e| e.is_a?(Sketchup::Group)}

      faces = faceGroup.entities.grep(Sketchup::Face)

      if faces.size > 1
        UI.messagebox("Плоскостей в выбранной группе больше 1й #{faces.size}")
      else
        face = faces[0]
      end
    end

    puts "face #{face}"
    puts "component #{component}"

    return {
      face: face,
      component: component
    }
  end

  def self.project_component_center_to_face
    model = Sketchup.active_model
    selection = model.selection

    inputObjects = find_input_objects
    # Разделяем выбранные объекты
    face = inputObjects[:face]
    component = inputObjects[:component]

    if !face
      UI.messagebox("Не выбрана плоскость проэкции")
    end

    if !component
      UI.messagebox("Не выбрана компонт проекции")
    end

    # Получаем плоскость и bounding box компонента
    plane =
    bounds = component.bounds

    # Вычисляем геометрический центр компонента
    center = bounds.center

    # стрелка направления компонента
    premitive_lay_definition = add_projection_arrow(model.active_entities,face,component, 100.mm)

    puts "premitive_lay_definition #{premitive_lay_definition}"

    projection = premitive_lay_definition[:projection]
    direction_vector = premitive_lay_definition[:direction_vector]

    #paste_primitive_at_point(projection)
    paste_with_orientation(projection,direction_vector)

    # Создаем результаты в модели
    model.start_operation("Project Component Center", true)

    # Добавляем точку центра (красная)
    center_point = model.active_entities.add_cpoint(center)
    center_point.material = "red"

    # Добавляем точку проекции (зеленая)
    proj_point = model.active_entities.add_cpoint(projection)
    proj_point.material = "green"

    # Добавляем линию проекции
    model.active_entities.add_line(center, projection)

    # Добавляем надписи
    add_label(model.active_entities, center, "Центр компонента")
    add_label(model.active_entities, projection, "Проекция центра")

    model.commit_operation

    UI.messagebox("Проекция центра компонента найдена:\nИсходная точка: #{center.to_s}\nПроекция: #{projection.to_s}")
  end

  def self.project_point_to_plane(point, plane)
    # Получаем параметры плоскости
    plane = plane.to_a
    a, b, c, d = plane

    # Вычисляем расстояние от точки до плоскости
    distance = (a * point.x + b * point.y + c * point.z + d)

    # Вычисляем проекцию
    Geom::Point3d.new(
      point.x - a * distance,
      point.y - b * distance,
      point.z - c * distance
    )
  end

  def self.add_projection_arrow(entities, face, component, length = 100.mm)

    bounds = component.bounds

    # Вычисляем геометрический центр компонента
    center = bounds.center

    plane = face.plane

    projection = project_point_to_plane(center, plane)

    # 1. Получаем bounding box компонента в его локальных координатах
    bb = component.definition.bounds

    # 2. Находим минимальную и среднюю оси bbox
    sizes = {
      x: bb.width,
      y: bb.height,
      z: bb.depth
    }
    sorted_axes = sizes.sort_by { |_, size| size }
    min_axis = sorted_axes[0][0]  # Самая короткая ось
    mid_axis = sorted_axes[1][0]  # Средняя ось

    # 3. Получаем локальные векторы осей
    local_min_vector = axis_to_vector(min_axis)
    local_mid_vector = axis_to_vector(mid_axis)

    # 4. Преобразуем в глобальные координаты
    transformation = component.transformation
    global_min_vector = transform_vector(local_min_vector, transformation)
    global_mid_vector = transform_vector(local_mid_vector, transformation)

    # 5. Получаем нормаль плоскости
    plane_normal = Geom::Vector3d.new(face.plane[0..2]).normalize

    # 6. Проецируем оба вектора на плоскость
    projected_min = project_vector_to_plane(global_min_vector, plane_normal)
    projected_mid = project_vector_to_plane(global_mid_vector, plane_normal)

    # 7. Выбираем вектор с наибольшей проекцией
    in_plane_vector = projected_min.length > projected_mid.length ? projected_min : projected_mid
    direction_vector = in_plane_vector.normalize!

    # 8. Создаем стрелку
    create_arrow(entities, projection, in_plane_vector, plane_normal, length)
    {
      projection: projection,
      direction_vector: direction_vector
    }
  end

  def self.axis_to_vector(axis)
    case axis
    when :x then Geom::Vector3d.new(1, 0, 0)
    when :y then Geom::Vector3d.new(0, 1, 0)
    else Geom::Vector3d.new(0, 0, 1)
    end
  end

  def self.transform_vector(vector, transformation)
    # Нулевая точка для преобразования
    origin = Geom::Point3d.new(0, 0, 0)
    # Преобразуем точку в конце вектора
    transformed_end = origin.transform(transformation) + vector.transform(transformation)
    # Возвращаем преобразованный вектор
    transformed_end - origin.transform(transformation)
  end

  def self.project_vector_to_plane(vector, plane_normal)
    # Формула проекции: v - (v·n)n
    dot_product = vector.dot(plane_normal)
    Geom::Vector3d.new(
      vector.x - plane_normal.x * dot_product,
      vector.y - plane_normal.y * dot_product,
      vector.z - plane_normal.z * dot_product
    )
  end

  def self.create_arrow(entities, start_point, direction, plane_normal, length)
    # Конечная точка стрелки
    end_point = Geom::Point3d.new(
      start_point.x + direction.x * length,
      start_point.y + direction.y * length,
      start_point.z + direction.z * length
    )

    # Основная линия стрелки
    arrow_line = entities.add_line(start_point, end_point)
    arrow_line.material = "red"

    # Создаем наконечник
    create_arrowhead(entities, start_point, end_point, plane_normal)
  end

  def self.create_arrowhead(entities, base, tip, normal)
    direction = Geom::Vector3d.new(tip.x - base.x, tip.y - base.y, tip.z - base.z)
    return if direction.length.zero?

    perp = direction.cross(normal).normalize
    size = direction.length * 0.3

    # Точки треугольника наконечника
    p1 = Geom::Point3d.new(
      tip.x - direction.x * size + perp.x * size,
      tip.y - direction.y * size + perp.y * size,
      tip.z - direction.z * size + perp.z * size
    )

    p2 = Geom::Point3d.new(
      tip.x - direction.x * size - perp.x * size,
      tip.y - direction.y * size - perp.y * size,
      tip.z - direction.z * size - perp.z * size
    )

    entities.add_face(tip, p1, p2).material = "red"
  end

  def self.add_label(entities, point, text)
    entities.add_text(text, point, Geom::Vector3d.new(0, 0, 10))
  end
end
