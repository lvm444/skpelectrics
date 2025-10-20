# Unit Testing Setup for SkpElectrics

This document describes the unit testing infrastructure set up for the SkpElectrics SketchUp plugin.

## Overview

The project now includes a comprehensive unit testing setup using Minitest framework. The testing infrastructure includes:

- **Test directory structure** with organized test files
- **Mock objects** for SketchUp API dependencies
- **Example test suite** for material dictionaries functionality
- **Test runner scripts** and Rake tasks

## Test Structure

```
test/
├── test_helper.rb          # Main test configuration and mocks
├── run_tests.rb            # Simple test runner script
└── unit/                   # Unit tests directory
    └── material_dictionaries_test.rb  # Example test suite
```

## Running Tests

### Method 1: Using Ruby directly
```bash
cd test
ruby -I. unit/material_dictionaries_test.rb
```

### Method 2: Using the test runner
```bash
cd test
ruby run_tests.rb
```

### Method 3: Using Rake (if available)
```bash
rake test
```

## Example Test: Material Dictionaries

The `material_dictionaries_test.rb` file provides a comprehensive example of testing the `ElectricalMaterialsDictionary` class:

### Test Coverage
- **Initialization**: Testing dictionary creation with empty model
- **Line Type Management**: Adding and retrieving line types
- **JSON Operations**: Loading from JSON strings and validation
- **Model Integration**: Saving and loading from SketchUp model attributes
- **Data Validation**: Testing valid and invalid data structures
- **Multiple Operations**: Testing with multiple line types

### Key Features Demonstrated
1. **Mock Objects**: Uses `TestMocks` module to simulate SketchUp API
2. **Setup/Teardown**: Proper test isolation with `setup` method
3. **Assertions**: Comprehensive assertion coverage
4. **Error Handling**: Testing both success and failure scenarios
5. **Private Method Testing**: Using reflection for private method validation

## Mock Objects

The `TestMocks` module provides mock implementations for SketchUp dependencies:

- `MockModel`: Simulates SketchUp Model with attribute dictionaries
- `MockAttributeDictionary`: Simulates attribute storage
- `MockUI`: Simulates UI interactions
- Helper methods for creating test data

## Adding New Tests

### 1. Create Test File
Create a new test file in `test/unit/` following the naming convention `*_test.rb`.

### 2. Basic Test Structure
```ruby
require_relative '../test_helper'
require_relative '../../src/skpelectrics/your_module'

class YourModuleTest < Minitest::Test
  def setup
    # Setup code here
  end

  def test_your_functionality
    # Test implementation
    assert_equal expected, actual
  end
end
```

### 3. Using Mocks
```ruby
def test_with_mocks
  mock_model = TestMocks.create_mock_model
  # Use mock_model in your tests
end
```

## Best Practices

1. **Isolation**: Each test should be independent
2. **Descriptive Names**: Use clear test method names
3. **Setup/Cleanup**: Use `setup` and `teardown` methods appropriately
4. **Assertions**: Use specific assertions for better error messages
5. **Mock Dependencies**: Always mock external dependencies like SketchUp API

## Dependencies

- **minitest**: Core testing framework (included in Ruby)
- **minitest-reporters**: Enhanced test output (optional)
- **json**: For JSON parsing (included in Ruby)

## Continuous Integration

The project includes GitHub Actions CI that automatically runs unit tests on:
- **Push to main branch**
- **Pull requests to main branch**
- **Tag pushes** (for releases)

### CI Configuration
The CI workflow (`/.github/workflows/sketchup-extension-build-ci.yaml`) includes:
- **Unit Test Job**: Runs all unit tests before building the extension
- **Ruby Setup**: Uses Ruby 2.7 environment
- **Dependency Installation**: Installs minitest-reporters for better output
- **Test Execution**: Runs all unit tests in the test directory

The testing setup is designed to work in CI environments by:
- Using mock objects instead of requiring SketchUp
- Having no external dependencies beyond Ruby
- Providing clear pass/fail output

## Code Coverage Reporting

The project uses **SimpleCov** for code coverage analysis with multiple reporting options:

### Available Coverage Reports

1. **HTML Report** (`coverage/index.html`)
   - Interactive web interface
   - Line-by-line coverage analysis
   - File and directory grouping
   - Color-coded coverage indicators

2. **Console Output**
   - Summary statistics in terminal
   - Coverage percentages by file group
   - Minimum coverage thresholds

3. **CI Artifacts**
   - Coverage reports uploaded as GitHub Actions artifacts
   - 30-day retention for historical comparison

### Running Coverage Locally

```bash
# Using Rake
rake coverage

# Direct Ruby execution (PowerShell)
cd test
$env:COVERAGE="true"; ruby -I. unit/material_dictionaries_test.rb

# Direct Ruby execution (Command Prompt)
cd test
set COVERAGE=true && ruby -I. unit/material_dictionaries_test.rb
```

### Coverage Configuration

- **Minimum Coverage**: 70% overall (adjusted for current test coverage)
- **Minimum File Coverage**: 60% per file
- **Groups**: Core, Dialogs, HTML
- **Exclusions**: Test files, vendor directories, CI files

### Current Coverage Status

**Currently Tracked Files:**
- `test/test_helper.rb` - Coverage tracked
- `test/unit/material_dictionaries_test.rb` - 97.48% coverage

**Files Successfully Loaded with SketchUp Mocks:**
- `src/skpelectrics/dialog_create_line.rb`
- `src/skpelectrics/dialog_create_report.rb`
- `src/skpelectrics/dialog_create_wiring.rb`
- `src/skpelectrics/dialog_edit_materials.rb`
- `src/skpelectrics/dialog_edit_tags.rb`
- `src/skpelectrics/dialog_settings.rb`
- `src/skpelectrics/electric_line_parser.rb`
- `src/skpelectrics/electric_line_transformation.rb`
- `src/skpelectrics/lines_search_manager.rb`
- `src/skpelectrics/material_dictionaries.rb`
- `src/skpelectrics/selection_manager.rb`
- `src/skpelectrics/sketchuputils.rb`
- `src/skpelectrics/skp_electrics_group_manager.rb`
- `src/skpelectrics/skpelectrics_wiretype.rb`
- `src/skpelectrics/tags_dictionary.rb`
- `src/skpelectrics/tag_manager.rb`
- `src/skpelectrics/tag_utils.rb`

**Files with Missing SketchUp Methods:**
- `src/skpelectrics/main.rb` - requires `file_loaded?` method
- `src/skpelectrics/settings.rb` - requires `file_loaded?` method
- `src/skpelectrics/skpelectrics.rb` - requires `file_loaded?` method
- `src/skpelectrics.rb` - requires `file_loaded?` method

**Coverage Status:**
- **Current Coverage**: 24.41% (278 / 1139 lines) - reflects all loaded source files
- **Branch Coverage**: Enabled but no branches tracked yet
- **Coverage includes**: All source files successfully loaded with SketchUp mocks
- **Coverage Directory**: `test/coverage/` (consistent across local and CI environments)

**Coverage Limitation:**
SimpleCov tracks coverage for files that are loaded and executed during tests. The current coverage percentage (24.41%) reflects that we've loaded all source files but only tested `material_dictionaries.rb`. As more tests are added for other modules, the overall coverage will increase.

**Successfully Loaded Files:** All 20 source files now load successfully with SketchUp mocks, including files that previously required `file_loaded?` method.

**CI Integration Fixed:**
- Coverage reports now generate in `test/coverage/` consistently
- GitHub Actions properly uploads coverage artifacts
- No more "No files were found" warnings in CI

### CI Integration

Coverage reports are automatically generated in CI and available as downloadable artifacts. The coverage badge in README shows the current coverage percentage for testable files.

## Next Steps

1. Add tests for other core modules:
   - `electric_line_parser.rb`
   - `lines_search_manager.rb`
   - `tag_manager.rb`
   - etc.

2. Set up coverage badge with dynamic percentage

3. Add integration tests for dialog interactions

4. Configure coverage thresholds for CI failures
