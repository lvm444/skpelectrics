require 'json'

module Lvm444Dev
  class ElectricalMaterialsDictionary
    attr_reader :materials_data

    def initialize(model)
      @model = model
      @materials_data = nil
      @dictionary_name = "Skp_Electrics_ElectricalMaterialsData"
      load_materials_data
    end

    # Сохраняет текущий справочник в модель SketchUp
    def save_to_model
      return if @materials_data.nil? || @materials_data.empty?

      # Получаем или создаем атрибутный словарь модели
      dict = @model.attribute_dictionary(@dictionary_name, true)

      # Сохраняем данные в виде JSON строки
      dict["materials_json"] = @materials_data.to_json

      # Сохраняем временную метку обновления
      dict["last_updated"] = Time.now.to_s

      puts "Справочник материалов успешно сохранен в модель"
      true
    rescue => e
      puts "Ошибка при сохранении справочника в модель: #{e.message}"
      false
    end

    def to_json
      @materials_data.to_json
    end

    # Загружает данные из модели
    def load_materials_data
      # Сначала пробуем загрузить из атрибутов модели
      if load_from_model_attributes
        return
      end

      # Если в модели нет, пробуем загрузить из файла
      if load_from_external_file
        return
      end

      # Если ничего не найдено, инициализируем пустым справочником
      @materials_data ||= {}
      puts "Справочник материалов не найден. Инициализирован пустой справочник."
    end

    # Добавляет новый тип линии с материалами
    def add_line_type(line_type, materials_hash)
      @materials_data ||= {}
      @materials_data[line_type] = materials_hash
      true
    rescue => e
      puts "Ошибка при добавлении типа линии: #{e.message}"
      false
    end

    def load_from_string(json_string)
      return false if json_string.nil? || json_string.empty?

      begin
        # Парсим JSON во временную переменную для валидации
        temp_data = JSON.parse(json_string)

        # Проверяем структуру данных
        unless valid_dictionary_structure?(temp_data)
          puts "Ошибка: некорректная структура справочника"
          return false
        end

        # Если все проверки пройдены, обновляем основной справочник
        @materials_data = temp_data
        puts "Справочник материалов успешно загружен из строки"
        true
      rescue JSON::ParserError => e
        puts "Ошибка парсинга JSON: #{e.message}"
        false
      rescue => e
        puts "Ошибка при загрузке из строки: #{e.message}"
        false
      end
    end

    def get_materials_by_type(type)
      @materials_data[type]
    end

    private

    def valid_dictionary_structure?(data)
      # 1. Проверяем что это хэш
      return false unless data.is_a?(Hash)

      # 2. Проверяем каждую запись
      data.each do |line_type, materials|
        # 2.1. Ключ типа линии должен быть строкой
        return false unless line_type.is_a?(String) && !line_type.empty?

        # 2.2. Материалы должны быть хэшем
        next if materials.nil? # Допускаем пустые значения
        return false unless materials.is_a?(Hash)

        # 2.3. Проверяем структуру материалов
        materials.each do |key, value|
          # Ключ может быть строкой или числом (преобразуется в строку при парсинге JSON)
          return false unless (key.is_a?(String) || key.is_a?(Numeric))

          # Значение должно быть строкой
          return false unless value.is_a?(String) && !value.empty?
        end
      end

      true
    rescue
      false
    end

    def load_from_model_attributes
      dict = @model.attribute_dictionary(@dictionary_name)
      return false unless dict && dict["materials_json"]

      begin
        @materials_data = JSON.parse(dict["materials_json"])
        puts "Справочник материалов загружен из атрибутов модели"
        true
      rescue JSON::ParserError => e
        puts "Ошибка при чтении данных из атрибутов модели: #{e.message}"
        false
      end
    end



    def load_from_external_file
      #json_file = find_json_file_in_model
      #return false unless json_file
      return false
      begin
        json_content = File.read(json_file)
        @materials_data = JSON.parse(json_content)
        puts "Справочник материалов загружен из внешнего файла"
        true
      rescue => e
        puts "Ошибка при чтении внешнего файла: #{e.message}"
        false
      end
    end
  end
end
