require 'csv'

class CucumberToSheets

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
      t == 'automated' ||
        t == 'positive' ||
        t == 'negative' ||
        t.start_with?('severity:') ||
        ['smoke', 'regression', 'sanity'].include?(t) ||
        t.start_with?('platform:') ||
        t.start_with?('team:') ||
        t.start_with?('story:') ||
        t == 'headless' ||
        t == 'not-headless'
    end

    columns.concat(custom_tags.map(&:capitalize).sort)

    CSV.open(output_file, 'w') do |csv|
      csv << columns

      @scenarios.each do |scenario|
        row = []
        row << scenario[:feature]
        row << scenario[:scenario]

        tags = scenario[:tags]

        # Automated column (checkbox representation)
        if columns.include?('Automated')
          row << (has_tag?(tags, 'automated') ? '✓' : '')
        end

        # Positive column
        if columns.include?('Positive')
          row << (has_tag?(tags, 'positive') ? '✓' : '')
        end

        # Negative column
        if columns.include?('Negative')
          row << (has_tag?(tags, 'negative') ? '✓' : '')
        end

        # Severity column
        if columns.include?('Severity')
          severity = extract_tag_value(tags, 'severity')
          row << (severity ? severity.capitalize : '')
        end

        # Smoke column
        if columns.include?('Smoke')
          row << (has_tag?(tags, 'smoke') ? '✓' : '')
        end

        # Regression column
        if columns.include?('Regression')
          row << (has_tag?(tags, 'regression') ? '✓' : '')
        end

        # Sanity column
        if columns.include?('Sanity')
          row << (has_tag?(tags, 'sanity') ? '✓' : '')
        end

        # Custom tags
        custom_tags.sort.each do |tag|
          row << (has_tag?(tags, tag) ? '✓' : '')
        end

        csv << row
      end
    end

    puts "\nCSV file generated: #{output_file}"
    puts "Total scenarios: #{@scenarios.count}"
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

end

# Main execution
if __FILE__ == $0
  if ARGV.empty?
    puts "Usage: ruby cucumber_to_sheets.rb <feature_file_or_directory> [output.csv]"
    puts "\nExamples:"
    puts "  ruby cucumber_to_sheets.rb features/login.feature"
    puts "  ruby cucumber_to_sheets.rb features/login.feature output.csv"
    puts "  ruby cucumber_to_sheets.rb features/"
    puts "  ruby cucumber_to_sheets.rb features/ all_features.csv"
    exit 1
  end

  input_path = ARGV[0]
  output_file = ARGV[1] || 'cucumber_scenarios.csv'

  parser = CucumberToSheets.new
  parser.process(input_path)
  parser.generate_csv(output_file)
end