# DEVREADME — SkpElectrics

SketchUp-плагин для электриков на Ruby. Распространяется как `.rbz`-архив.

## Структура проекта

```
├── src/
│   ├── skpelectrics.rb              # Точка входа: регистрация расширения, dev-перезагрузка
│   └── skpelectrics/
│       ├── main.rb                  # Меню, тулбар, команды
│       ├── *.rb                     # Модули логики, диалогов, парсеров
│       ├── html/                    # HTML/CSS/JS диалогов
│       └── images/                  # Иконки тулбара
├── test/
│   ├── test_helper.rb               # Моки SketchUp API
│   ├── unit/*_test.rb               # Unit-тесты (Minitest)
│   └── skpelectrics-it/             # Интеграционные тесты
├── Gemfile                           # Зависимости (sketchup-api-stubs, solargraph, minitest…)
├── Rakefile                          # `rake test`, `rake coverage`
└── .editorconfig / .rubocop.yml      # Форматирование и линтер
```

## Как указать папку проекта для разработки

Чтобы SketchUp загружал исходники из локальной папки (а не из `.rbz`), нужно задать путь одним из способов:

### Способ 1 — диалог выбора папки
Открой в SketchUp: **Расширения → Разработчик → Консоль языка Ruby** и выполни:
```ruby
Lvm444Dev::SkpElectrics.choose_dev_dir
```

### Способ 2 — указать путь явно
```ruby
Lvm444Dev::SkpElectrics.set_dev_dir('<путь/к/src/skpelectrics>')
```

## Как обновить проект после изменений

После правки `.rb`-файлов перезагрузи их в SketchUp без перезапуска:

```ruby
Lvm444Dev::SkpElectrics.reload_dev
```

Эта команда загружает все `*.rb` из dev-папки заново.

## Запуск тестов

Тесты запускаются через **системный Ruby**, а не встроенный в SketchUp. Установи Ruby 2.7+ ([rubyinstaller.org](https://rubyinstaller.org/)), затем:

```bash
bundle install              # установить зависимости (один раз)
bundle exec rake test       # unit-тесты
bundle exec rake coverage   # тесты с покрытием (SimpleCov) → test/coverage/index.html
```

## Сборка .rbz

Запаковать `src/` в `.rbz` можно через `skippy` (см. Gemfile) или вручную — это zip-архив `.rbz`, внутри которого лежат `skpelectrics.rb` и папка `skpelectrics/`.

## Ключевые моменты

- **Имена групп** кабелей парсятся по шаблону: `<Код>-<Тип>-<Помещение> <Описание>` (см. [`electric_line_parser.rb`](src/skpelectrics/electric_line_parser.rb)).
- **Диалоги** — HTML-страницы, открываемые через `UI::HtmlDialog`, лежат в [`html/`](src/skpelectrics/html).
- **Линтер**: `rubocop` с плагином `rubocop-sketchup`.
- **CI**: GitHub Actions запускает тесты при push/PR в `main`.
