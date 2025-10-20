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

## Next Steps

1. Add tests for other core modules:
   - `electric_line_parser.rb`
   - `lines_search_manager.rb`
   - `tag_manager.rb`
   - etc.

2. Set up CI/CD pipeline to run tests automatically

3. Add code coverage reporting with SimpleCov

4. Create integration tests for dialog interactions
