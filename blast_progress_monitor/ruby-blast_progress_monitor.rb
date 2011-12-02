#!/usr/bin/env ruby

require 'optparse'
require 'date'
require 'time'

class Job
  attr_accessor :input, :output, :starttime

  def lasthit_index
    `grep ">" #{File.absolute_path(self.input)} | grep -n #{self.output.lasthit}` =~ /^(\d+)/
    $1.to_i
  end

  def progress
    self.lasthit_index.to_f / self.input.read_count.to_f * 100
  end

  def hitrate
    self.output.uniq_hitcount.to_f / self.lasthit_index.to_f * 100 
  end

  def due
    if self.starttime
      return Time.at((((Time.now.to_i - self.starttime) * self.input.read_count) / self.lasthit_index) + Time.now.to_i)
    else
      return "Could not be estimated" 
    end
  end
end

class Shellscript < File

  def input
    contents = File.open(self).read
    abort("Shell script #{self} does not specify an input with -i") unless contents =~ /-i\s(\S+)/
    Multifasta.new(File.absolute_path($1, File.dirname(self)))
  end

  def output
    contents = File.open(self).read
    abort("Shell script #{self} does not specify an output with -o") unless contents =~ /-o\s(\S+)/
    BlastOutput.new(File.absolute_path($1, File.dirname(self)))
  end

  def starttime
    if `qstat -r`.include?(File.basename(self))
      starttime = Time.new
      `qstat -r`.each_line do |line|
        if line =~ /^(\d+)/
          starttime = DateTime.strptime("#{line.split(/\s+/)[5]} #{line.split(/\s+/)[6]}", "%m/%d/%Y %H:%M:%S").to_time
        end
        if line =~ /#{File.basename(self)}/
          return starttime.to_i
        end
      end
    else
      return false
    end
  end
end

class Multifasta < File

  def read_count
    `grep ">" #{File.absolute_path(self)} | wc -l` =~ /^(\d+)/
    $1.to_i
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
    shellscript = Shellscript.new(file)
    job.input = shellscript.input
    job.output = shellscript.output
    if shellscript.starttime
      job.starttime = shellscript.starttime
    end
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
  puts ""
  puts "DUE:           #{job.due}"
  puts "==========="
end
