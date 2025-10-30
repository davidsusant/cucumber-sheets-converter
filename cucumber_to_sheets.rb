require 'csv'
require 'fileutils'
require 'json'

class CucumberToSheets

  OUTPUT_DIR = 'output'
  CHECKBOX_COLUMNS = ['Automated', 'Positive', 'Negative', 'Smoke', 'Regression', 'Sanity']

  def initialize
    @all_tags = Set.new
    @scenarios = []
  end

  def process(input_path)
    if File.directory?(input_path)
      parse_directory(input_path)
    elsif File.file?(input_path)
      parse_file(input_path)
    else
      puts "Error: #{input_path} is not a valid file or directory"
      exit 1
    end
  end

  def parse_directory(dir_path)
    Dir.glob(File.join(dir_path, '**', '*.feature')).each do |file|
      puts "Parsing: #{file}"
      parse_file(file)
    end
  end

  def parse_file(file_path)
    content = File.read(file_path)
    lines = content.lines.map(&:strip)

    feature_tags = []
    feature_name = ''
    current_scenario = nil
    current_tags = []

    lines.each do |line|
      next if line.empty? || line.start_with?('#')

      if line.start_with?('@')
        # Collect tags
        tags = line.scan(/@([\w:.-]+)/).flatten
        current_tags.concat(tags)
      elsif line.start_with?('Feature:')
        feature_name = line.sub('Feature:', '').strip
        feature_tags = current_tags.dup
        current_tags = []
      elsif line.start_with?('Scenario:') || line.start_with?('Scenario Outline:')
        scenario_name = line.sub(/^Scenario(?: Outline)?:/, '').strip

        # Combine feature tags first, then scenario tags (so scenario tags can override)
        # For duplicate tag prefixes (like severity:), later tags will take precedence
        all_scenario_tags = feature_tags + current_tags

        current_scenario = {
          feature: feature_name,
          scenario: scenario_name,
          tags: all_scenario_tags
        }

        @scenarios << current_scenario
        @all_tags.merge(all_scenario_tags)
        current_tags = []
      elsif line.start_with?('Background:')
        # Skip background sections
        current_tags = []
      end
    end
  end

  def generate_csv(output_file)
    ensure_output_directory

    # Ensure output file is in output directory
    output_path = if output_file.start_with?(OUTPUT_DIR)
                    output_file
                  else
                    File.join(OUTPUT_DIR, File.basename(output_file))
                  end

    # Prepare columns based on discovered tags
    columns = ['Feature', 'Scenario']

    # Add standard boolean columns
    columns << 'Automated' if @all_tags.any? { |t| t == 'automated' }
    columns << 'Positive' if @all_tags.any? { |t| t == 'positive' }
    columns << 'Negative' if @all_tags.any? { |t| t == 'negative' }

    # Add severity column
    columns << 'Severity' if @all_tags.any? { |t| t.start_with?('severity:') }

    # Add test type columns
    columns << 'Smoke' if @all_tags.any? { |t| t == 'smoke' }
    columns << 'Regression' if @all_tags.any? { |t| t == 'regression' }
    columns << 'Sanity' if @all_tags.any? { |t| t == 'sanity' }

    # Add any other custom tags as additional columns
    custom_tags = @all_tags.reject do |t|
      t == 'automated' || t == 'positive' || t == 'negative' ||
        t.start_with?('severity:') ||
        ['smoke', 'regression', 'sanity'].include?(t) ||
        t.start_with?('platform:') ||
        t.start_with?('team:') ||
        t.start_with?('story:') ||
        t == 'headless' ||
        t == 'not-headless'
    end

    columns.concat(custom_tags.map(&:capitalize).sort)

    CSV.open(output_path, 'w') do |csv|
      csv << columns

      @scenarios.each do |scenario|
        row = []
        row << scenario[:feature]
        row << scenario[:scenario]

        tags = scenario[:tags]

        # Automated column
        if columns.include?('Automated')
          row << (has_tag?(tags, 'automated') ? 'TRUE' : 'FALSE')
        end

        # Positive column
        if columns.include?('Positive')
          row << (has_tag?(tags, 'positive') ? 'TRUE' : 'FALSE')
        end

        # Negative column
        if columns.include?('Negative')
          row << (has_tag?(tags, 'negative') ? 'TRUE' : 'FALSE')
        end

        # Severity column
        if columns.include?('Severity')
          severity = extract_tag_value(tags, 'severity')
          row << (severity ? severity.capitalize : '')
        end

        # Smoke column
        if columns.include?('Smoke')
          row << (has_tag?(tags, 'smoke') ? 'TRUE' : 'FALSE')
        end

        # Regression column
        if columns.include?('Regression')
          row << (has_tag?(tags, 'regression') ? 'TRUE' : 'FALSE')
        end

        # Sanity column
        if columns.include?('Sanity')
          row << (has_tag?(tags, 'sanity') ? 'TRUE' : 'FALSE')
        end

        # Custom tags
        custom_tags.sort.each do |tag|
          row << (has_tag?(tags, tag) ? 'TRUE' : 'FALSE')
        end

        csv << row
      end
    end

    puts "\nCSV file generated: #{output_path}"
    puts "Total scenarios: #{@scenarios.count}"
    puts "\nIMPORTANT: After importing to Google Sheets:"
    puts "1. Select checkbox columns"
    puts "2. Go to Insert > Checkbox"
    puts "3. Google Sheets will convert TRUE/FALSE to checkboxes automatically"

    output_path
  end

  def ensure_output_directory
    FileUtils.mkdir_p(OUTPUT_DIR) unless File.directory?(OUTPUT_DIR)
  end

  def has_tag?(tags, tag_name)
    tags.any? { |t| t.downcase == tag_name.downcase }
  end

  def extract_tag_value(tags, prefix)
    # Find all tags with this prefix and take the last one (scenario-level overrides feature-level)
    matching_tags = tags.select { |t| t.start_with?("#{prefix}:") }
    return nil if matching_tags.empty?
    matching_tags.last.split(':', 2)[1]
  end

  def generate_google_sheets_json(output_file)
    ensure_output_directory

    # Ensure output file is in output directory
    base_name = File.basename(output_file, File.extname(output_file))
    json_path = File.join(OUTPUT_DIR, "#{base_name}_sheets_format.json")

    # Prepare columns
    columns = ['Feature', 'Scenario']
    columns << 'Automated' if @all_tags.any? { |t| t == 'automated' }
    columns << 'Positive' if @all_tags.any? { |t| t == 'positive' }
    columns << 'Negative' if @all_tags.any? { |t| t == 'negative' }
    columns << 'Severity' if @all_tags.any? { |t| t.start_with?('severity:') }
    columns << 'Smoke' if @all_tags.any? { |t| t == 'smoke' }
    columns << 'Regression' if @all_tags.any? { |t| t == 'regression' }
    columns << 'Sanity' if @all_tags.any? { |t| t == 'sanity' }

    custom_tags = @all_tags.reject do |t|
      t == 'automated' || t == 'positive' || t == 'negative' ||
        t.start_with?('severity:') || ['smoke', 'regression', 'sanity'].include?(t) ||
        t.start_with?('platform:') || t.start_with?('team:') || t.start_with?('story:') ||
        t == 'headless' || t == 'not-headless'
    end

    columns.concat(custom_tags.map(&:capitalize).sort)

    # Build data structure for Google Sheets API
    sheets_data = {
      title: base_name.gsub('_', ' ').split.map(&:capitalize).join(' '),
      columns: columns,
      checkbox_columns: CHECKBOX_COLUMNS & columns,
      rows: []
    }

    @scenarios.each do |scenario|
      row_data = {}
      tags = scenario[:tags]

      columns.each do |col|
        case col
        when 'Feature'
          row_data[col] = scenario[:feature]
        when 'Scenario'
          row_data[col] = scenario[:scenario]
        when 'Automated'
          row_data[col] = has_tag?(tags, 'automated')
        when 'Positive'
          row_data[col] = has_tag?(tags, 'positive')
        when 'Negative'
          row_data[col] = has_tag?(tags, 'negative')
        when 'Severity'
          severity = extract_tag_value(tags, 'severity')
          row_data[col] = severity ? severity.capitalize : ''
        when 'Smoke'
          row_data[col] = has_tag?(tags, 'smoke')
        when 'Regression'
          row_data[col] = has_tag?(tags, 'regression')
        when 'Sanity'
          row_data[col] = has_tag?(tags, 'sanity')
        else
          row_data[col] = has_tag?(tags, col.downcase)
        end
      end

      sheets_data[:rows] << row_data
    end

    File.write(json_path, JSON.pretty_generate(sheets_data))
    puts "\nGoogle Sheets format JSON generated: #{json_path}"
    puts "Use this JSON with Google Sheets API to create native spreadsheets"

    json_path
  end
end

# Main execution
if __FILE__ == $0
  if ARGV.empty?
    puts "Usage: ruby cucumber_to_sheets.rb <feature_file_or_directory> [output_name]"
    puts "\nExamples:"
    puts "  ruby cucumber_to_sheets.rb features/login.feature"
    puts "  ruby cucumber_to_sheets.rb features/login.feature my_tests"
    puts "  ruby cucumber_to_sheets.rb features/"
    puts "  ruby cucumber_to_sheets.rb features/ all_features"
    puts "\nOutput:"
    puts "  - CSV files are saved in 'output/' directory"
    puts "  - TRUE/FALSE values for checkboxes"
    puts "  - JSON format for Google Sheets API integration"
    exit 1
  end

  input_path = ARGV[0]
  output_name = ARGV[1] || 'cucumber_scenarios'

  # Add .csv extenstion if not present
  output_file = output_name.end_with?('.csv') ? output_name : "#{output_name}.csv"

  parser = CucumberToSheets.new
  parser.process(input_path)
  csv_path = parser.generate_csv(output_file)
  json_path = parser.generate_google_sheets_json(output_file)

  puts "\n" + "="*60
  puts "NEXT STEPS:"
  puts "="*60
  puts "1. Import #{csv_path} to Google Sheets"
  puts "2. Select columns: Automated, Positive, Negative, Smoke, Regression, Sanity"
  puts "3. Click Insert > Checkbox (Sheets will convert TRUE/FALSE to checkboxes)"
  puts "\nOR use Google Sheets API with #{json_path}"
end