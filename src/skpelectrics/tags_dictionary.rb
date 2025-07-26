require 'sketchup.rb'
require 'extensions.rb'

module Lvm444Dev
    # Класс для работы со справочником меток в SketchUp
  class TagsDictionary
    attr_reader :groups, :tag_types

    # Инициализация
    def initialize(model)
      @model = model
      @groups = {}
      @tag_types = {}
      @dictionary_name = 'Skp_Electrics_TagsDictionary'
      load_from_model
    end

    # Загрузка данных из модели
    def load_from_model
      dict = @model.get_attribute(@dictionary_name, 'Data')
      load_from_string(dict)
    end

    def load_from_string(dict)
      if (!dict.nil?)
        if dict.is_a?(String)
          data = JSON.parse(dict)
          @groups = data['groups'] || {}
          @tag_types = data['tagTypes'] || {}
        end
      else
        # Если справочник пуст инициализируем пустой по умолчанию
        @groups = {}
        @tag_types = {}
      end

      # Конвертируем ключи групп из строк в символы для единообразия
      @groups = @groups.transform_keys(&:to_s)
      @groups.each do |path, group|
        group.transform_keys!(&:to_s)
        group['children'] ||= []
      end

      @tag_types = @tag_types.transform_keys(&:to_s)
    end

    def to_json
      data = {
        'groups' => prepare_groups_for_saving,
        'tagTypes' => prepare_tag_types_for_saving
      }
      data
    end

    def save_to_model
      # Подготовка данных с валидацией
      data = {
        'groups' => prepare_groups_for_saving,
        'tagTypes' => prepare_tag_types_for_saving
      }

      puts "data before save #{data}"

      # Сохранение только если данные прошли валидацию
      if data_valid?(data)
        @model.set_attribute(@dictionary_name, 'Data', data.to_json)
        true
      else
        false
      end
    end

    # Получение всех групп в виде дерева
    def groups_tree
      roots = @groups.select { |_, g| g['parent'].nil? }.keys
      build_tree(roots)
    end

    # Получение меток группы
    def tags_for_group(group_path)
      @tag_types.select { |_, tag| tag['groupPath'] == group_path }
    end

    private

    def clean_groups_data(groups)
      {}.tap do |clean_groups|
        groups.each do |path, group|
          next unless path.is_a?(String)

          clean_groups[path] = {
            'name' => group['name'].to_s,
            'parent' => group['parent'].is_a?(String) ? group['parent'] : nil,
            'children' => [],
            'color' => valid_hex_color?(group['color']) ? group['color'] : '#CCCCCC'
          }
        end
      end
    end

    def clean_tag_types_data(tag_types)
      {}.tap do |clean_tags|
        tag_types.each do |prefix, tag|
          next unless prefix.is_a?(String) && valid_tag_prefix?(prefix)

          clean_tags[prefix] = {
            'description' => tag['description'].to_s,
            'groupPath' => tag['groupPath'].to_s,
            'color' => valid_hex_color?(tag['color']) ? tag['color'] : '#CCCCCC'
          }
        end
      end
    end

    def rebuild_group_relationships!
      # Восстанавливаем связи parent-children
      @groups.each do |path, group|
        next if group['parent'].nil?

        parent_group = @groups[group['parent']]
        parent_group['children'] << path if parent_group
      end

      # Очищаем дубликаты и несуществующие ссылки
      @groups.each do |_, group|
        group['children'].uniq!
        group['children'].reject! { |child| !@groups.key?(child) }
      end
    end

    def prepare_groups_for_saving
      {}.tap do |groups|
        @groups.each do |path, group|
          groups[path] = {
            'name' => group['name'],
            'parent' => group['parent'],
            'children' => group['children'],
            'color' => group['color']
          }
        end
      end
    end

    def prepare_tag_types_for_saving
      {}.tap do |tags|
        @tag_types.each do |prefix, tag|
          tags[prefix] = {
            'description' => tag['description'],
            'groupPath' => tag['groupPath'],
            'color' => tag['color']
          }
        end
      end
    end

    def data_valid?(data)
      groups = data['groups']
      tag_types = data['tagTypes']

      # Проверка групп
      groups.each do |path, group|
        return false unless path.is_a?(String)
        return false unless valid_group_structure?(group)
        return false unless group['parent'].nil? || groups.key?(group['parent'])
      end

      # Проверка типов меток
      tag_types.each do |prefix, tag|
        return false unless valid_tag_prefix?(prefix)
        return false unless valid_tag_structure?(tag)
        return false unless groups.key?(tag['groupPath'])
      end

      true
    end

    def valid_group_structure?(group)
      group.is_a?(Hash) &&
      group['name'].is_a?(String) &&
      (group['parent'].nil? || group['parent'].is_a?(String)) &&
      group['children'].is_a?(Array) &&
      valid_hex_color?(group['color'])
    end

    def valid_tag_structure?(tag)
      tag.is_a?(Hash) &&
      tag['description'].is_a?(String) &&
      tag['groupPath'].is_a?(String) &&
      valid_hex_color?(tag['color'])
    end

    def valid_tag_prefix?(prefix)
      prefix.is_a?(String) && prefix.match?(/^[A-ZА-Я0-9]+$/)
    end

    def valid_hex_color?(color)
      color.is_a?(String) && color.match?(/^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/)
    end

    # Рекурсивное построение дерева групп
    def build_tree(group_paths)
      group_paths.map do |path|
        group = @groups[path]
        {
          'path' => path,
          'name' => group['name'],
          'color' => group['color'],
          'children' => group['children'] ? build_tree(group['children']) : []
        }
      end
    end
  end
end
