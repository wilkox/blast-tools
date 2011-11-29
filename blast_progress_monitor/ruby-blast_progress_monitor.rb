#!/usr/bin/env ruby

require 'optparse'

class Multifasta < File
  def read_names
    names = []
    self.readlines.each do |line|
      names << line.scan(/^>(\S+)/)
    end 
    names
  end
end

class BlastOutput < File
  def read_names
    names = []
    self.readlines.each do |line|
      names << line.scan(/^(\S+)/)
    end
    names
  end
end

#parse command line options
optparse = OptionParser.new do |opts|

  opts.on( '-i FILE', '--sample-file FILE', '--input FILE', '--sample FILE' ) do |file|
    @infile = Multifasta.new(file) != nil
  end

  opts.on( '-o FILE', '--blast-output FILE', '--output FILE' ) do |file|
    @outfile = BlastOutput.new(file) != nil
  end
end
optparse.parse!

