#!/usr/bin/env ruby

# A script to convert README.md to html,
# with html parsing so I automatically can plug in links
# to Wikipedia, RottenTomatoes, etc.

require 'tempfile'
require './src/anchor'

SOURCE = 'README.md'
OUTPUT = 'index.html'
TEMPLATE = 'src/template.html'


def main
  text = File.read(SOURCE)
  text = to_markdown text # problem: this destroys https:// links with '_' in them
  text = linkify text
  text = with_template text

  File.open(OUTPUT, 'w+') do |file|
    file.write text
  end
end

private

# Rewrite https:// links with a <a> tag
# if they are not in a markdown []() tag
def linkify text
  Anchored::Linker.auto_link text
end

def to_markdown text
  temp = Tempfile.new
  File.write(temp, text, mode: 'w+')
  `markdown #{SOURCE} > #{temp.path}`
  File.read(temp.path)
end

def with_template text
  File.open(TEMPLATE, 'r') do |file|
    template = file.read
    return template.sub('BODY') { text }
  end
end

main
