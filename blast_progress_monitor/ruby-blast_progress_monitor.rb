#!/usr/bin/env ruby

require 'optparse'

class Job
  attr_accessor :input, :output

  def progress
    print "CALCULATING PROGRESS..."
    ireads = self.input.reads
    puts "\rPROGRESS:      #{ireads.index(self.output.lasthit).to_f / ireads.length.to_f * 100}"
  end
end

class Multifasta < File

  def reads
    names = []
    self.readlines.each do |line|
      names << line.scan(/^>(\S+)/).flatten
    end 
    names.reject! { |c| c.empty? }.flatten
  end
end

class BlastOutput < File
  
  def lasthit
    # self.readlines.last.scan(/^(\S+)/).flatten.first.to_s # slow
    `tail -1 #{self.path}`.scan(/^(\S+)/).flatten.first.to_s # faster
  end
end

#parse command line options
jobs = []
optparse = OptionParser.new do |opts|

  opts.on( '-i FILE', '--sample-file FILE', '--input FILE', '--sample FILE' ) do |file|
    job = Job.new
    job.input = Multifasta.new(file)
    opts.on( '-o FILE', '--blast-output FILE', '--output FILE' ) do |file|
      job.output = BlastOutput.new(file)
      jobs << job
    end
  end

  opts.on( '-s FILE', '--shell-script FILE' ) do |file|
    job = Job.new
    contents = File.open(file).read
    abort("Shell script #{file} does not specify an input with -i") unless contents =~ /-i\s(\S+)/
    job.input = Multifasta.new(File.absolute_path($1, File.dirname(file)))
    abort("Shell script #{file} does not specify an output with -o") unless contents =~ /-o\s(\S+)/
    job.output = BlastOutput.new(File.absolute_path($1, File.dirname(file)))
    jobs << job
  end
end

####
##MAIN
####

optparse.parse!
jobs.each do |job|
  puts "==========="
  puts "INPUT:         #{job.input.path}"
  puts "OUTPUT:        #{job.output.path}"
  job.progress
  puts "==========="
end
