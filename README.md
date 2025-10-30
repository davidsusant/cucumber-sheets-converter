# Cucumber to Google Sheet Exporter

A Ruby script that extract Cucumber feature files and converts them into CSV format compatible with Google Sheets. 
All Cucumber tags are automatically converted into columns.

## Features

- ✅ Parse single feature file or entire directory
- ✅ Extract all scenarios with their tags
- ✅ Automatically detect and create columns for all tags
- ✅ Support for feature-level and scenario-level tags
- ✅ Handle tag formats like `@automated`, `@severity:critical`, etc.
- ✅ Export to CSV format ready for Google Sheets import
- ✅ Checkmark (✓) representation for boolean tags

## Requirements

- Ruby 2.7 or higher (uses built-in CSV library)

## Installation

No additional gems required. The script uses only Ruby standard library.

```bash
# Make the script executable (optional)
chmod +x cucumber_to_sheets.rb
```

## Usage

### Basic Usage

```bash
# Parse a single feature file
ruby cucumber_to_sheets.rb path/to/feature_file.feature

# Parse all feature files in a directory
ruby cucumber_to_sheets.rb path/to/features

# Specify custom output filename
ruby cucumber_to_sheets.rb path/to/features/ my_output.csv
```

### Examples

```bash
# Parse the sample feature file
ruby cucumber_to_sheets.rb features/login.feature

# Parse all features in a directory and save to a custom file
ruby cucumber_to_sheets.rb features/ test_cases.csv
```