require 'yaml'
require 'paxmex/schema'

class Paxmex::Parser
  SCHEMATA = %w(epraw eptrn).reduce({}) do |h, fn|
    h.merge(fn => Paxmex::Schema.new(YAML::load(File.open("config/#{fn}.yml"))))
  end

  attr_reader :schema

  def initialize(path, opts = {})
    @path = path
    @schema = SCHEMATA[opts[:schema]]
  end

  def raw
    @raw ||= File.read(@path).chomp
  end

  def parse
    return @parsed if @parsed

    content = raw.split("\n")

    # Parse the trailing section first so that we don't need
    # to consider it when parsing recurring sections
    trailer_section = schema.sections.detect(&:trailer?)
    trailer_content = [content.slice!(-1)]
    @parsed = parse_section(content: trailer_content, section: trailer_section)

    schema.sections.reject(&:trailer?).each do |section|
      @parsed.merge!(
        parse_section(
          content: section.recurring? ? content : [content.slice!(0)],
          section: section))
    end

    @parsed
  end

  private

  def parse_section(opts = {})
    raise 'Content must be provided' unless content = opts[:content]
    raise 'Section must be provided' unless section = opts[:section]

    result = {}
    abstract_section = section if section.abstract?

    content.each do |section_content|
      if abstract_section
        start, final = abstract_section.type_field
        section_type = section_content[start..final]
        section = abstract_section.section_for_type(section_type)
      end

      result[section.key] ||= [] if section.recurring?

      p = {}
      section.fields.each do |field|
        p[field.name] = section_content[field.start..field.final]
      end

      if section.recurring?
        result[section.key] << p
      else
        result[section.key] = p
      end
    end

    result
  end
end
