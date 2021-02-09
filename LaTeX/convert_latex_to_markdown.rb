#!/usr/bin/env ruby

require 'byebug'

data = File.open('work_tmp.tex', 'r').read

data.lines.each do |line|
  line = line.strip

  if m = line.match(/(\\RT\{(.*)\}\{(.*)\}).*/)
    line = line.gsub(m[1]) { '' }
    line = "* #{m[3]} #{line} [🍅](https://www.rottentomatoes.com/m/#{m[2]})"
  end

  if m = line.match(/(\\TR\{(.*)\}\{(.*)\}).*/)
    line = line.gsub(m[1]) { '' }
    line = "* #{m[3]} #{line} [📰](https://www.telerama.fr/cinema/films/#{m[2]})"
  end

  if m = line.match(/(\\TRtele\{(.*)\}\{(.*)\}).*/)
    line = line.gsub(m[1]) { '' }
    line = "* #{m[3]} #{line} [📰](https://television.telerama.fr/cinema/films/#{m[2]})"
  end

  puts line
end

