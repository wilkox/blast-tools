#!/usr/bin/env ruby

require 'optparse'

class Job
  attr_accessor :input, :output

  def lasthit_index
    `grep ">" #{File.absolute_path(self.input)} | grep -n #{self.output.lasthit}` =~ /^(\d+)/
    $1
  end

  def progress
    self.lasthit_index.to_f / self.input.read_count.to_f * 100
  end

  def hitrate
    self.output.uniq_hitcount.to_f / self.lasthit_index.to_f * 100 
  end
end

class Multifasta < File

  def read_count
    `grep ">" #{File.absolute_path(self)} | wc -l` =~ /^(\d+)/
    $1
  end
end

class BlastOutput < File

  def uniq_hitcount
    `cut -f1 #{self.path} | uniq | wc -l` =~ /(\d+)/
    $1
  end
  
  def lasthit
    `tail -1 #{self.path}`.scan(/^(\S+)/).flatten.first.to_s
  end

  def hit_count
    `wc -l #{self.path}` =~ /(\d+)/
    $1
  end
end

####
##MAIN
####

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

optparse.parse!

jobs.each do |job|
  puts "==========="
  puts "INPUT:         #{job.input.path} [#{job.input.read_count} reads]"
  puts "OUTPUT:        #{job.output.path} [#{job.output.hit_count} hits]"
  puts ""
  puts "PROGRESS:      #{job.progress}%"
  puts ""
  puts "HIT RATE:      #{job.hitrate}%"
  puts "==========="
end
