module Lvm444Dev
  module CustomSymbols
    class SymbolManager
      def initialize
        @symbols = {}
        @current_symbol = nil
      end

      def create_ui
        # Create the main dialog
        dialog = UI::WebDialog.new("Custom Symbol Manager", false, "CustomSymbolManager", 400, 300, 150, 150, true)
        dialog.set_file(File.join(__dir__, "symbol_ui.html"))

        # Add JavaScript to HTML interface
        html = <<-HTML
        <html>
        <head>
          <style>
            body { font-family: Arial, sans-serif; padding: 10px; }
            button { padding: 5px 10px; margin: 5px; }
            #symbolList { width: 100%; height: 150px; }
          </style>
        </head>
        <body>
          <h3>Custom Symbol Manager</h3>
          <button onclick="sketchup.createSymbol()">Create New Symbol</button>
          <button onclick="sketchup.pasteSymbol()">Paste Selected Symbol</button>
          <hr>
          <select id="symbolList" size="5"></select>
          <button onclick="sketchup.deleteSymbol()">Delete Symbol</button>
        </body>
        <script>
          function updateSymbolList(symbols) {
            const list = document.getElementById('symbolList');
            list.innerHTML = '';
            symbols.forEach(symbol => {
              const option = document.createElement('option');
              option.value = symbol[0];
              option.textContent = symbol[1];
              list.appendChild(option);
            });
          }
        </script>
        </html>
        HTML

        dialog.set_html(html)

        # Bridge between Ruby and JavaScript
        dialog.add_action_callback("createSymbol") { |action, value|
          create_symbol
        }

        dialog.add_action_callback("pasteSymbol") { |action, value|
          paste_symbol
        }

        dialog.add_action_callback("deleteSymbol") { |action, value|
          delete_symbol
        }

        # Show the dialog
        dialog.show
      end

      def create_symbol
        model = Sketchup.active_model
        selection = model.selection

        if selection.empty?
          UI.messagebox("Please select geometry to convert to a symbol.")
          return
        end

        # Prompt for symbol name
        prompts = ["Symbol Name:", "Description:"]
        defaults = ["MySymbol", ""]
        input = UI.inputbox(prompts, defaults, "Create New Symbol")
        return unless input

        name, description = input

        # Create a component definition from the selection
        definition = model.definitions.add(name)
        definition.description = description

        # Add the selected entities to the definition
        transformation = Geom::Transformation.new
        definition.entities.add_entities(selection.to_a, transformation)

        # Store the symbol
        @symbols[name] = definition
        @current_symbol = definition

        # Clear the original geometry
        model.entities.erase_entities(selection.to_a)

        UI.messagebox("Symbol '#{name}' created successfully!")
      end

      def paste_symbol
        model = Sketchup.active_model

        if @current_symbol.nil? && @symbols.empty?
          UI.messagebox("No symbols available. Create one first.")
          return
        end

        # If we have a current symbol, use that
        definition = @current_symbol || @symbols.values.first

        # Place the symbol at the origin (user can move it)
        model.entities.add_instance(definition, Geom::Transformation.new)

        UI.messagebox("Symbol instance placed in model.")
      end

      def delete_symbol
        # Implement symbol deletion logic here
        UI.messagebox("Symbol deletion feature not yet implemented.")
      end
    end

    def self.activate
      @manager ||= SymbolManager.new
      @manager.create_ui
    end
  end

  # Add menu item to access the tool
  UI.menu("Plugins").add_item("Custom Symbols") {
    CustomSymbols.activate
  }
end
