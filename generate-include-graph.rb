#generate-include-graph.rb
#Reads through a set of files, following its includes,
#and outputs a graph describing them

require 'find'
require 'pathname'

require 'optparse'

require 'rgl/dot'
require 'rgl/implicit'

@include_paths = []
@scanned_files = []
@includes = Hash.new{|h, k| h[k] = []}
@output_filename = "includes"

OptionParser.new do |opts|
	opts.banner = "Usage: generate-include-graph.rb [-I path] [-o filename] file1 file2..."

	opts.on("-I", "--include PATH", "Add PATH to search paths for includes") do |inc|
		@include_paths << Pathname.new(inc).realpath
	end
	opts.on("-o", "--output FILE", "Set output filename to FILE") do |file|
		@output_filename = file
	end
end.parse!

def find_file(filename, working_dir)
	out_file = nil
	thisdirfile = "#{working_dir}/#{filename}"
	if FileTest.exist?(filename) then
		out_file = filename
	elsif FileTest.exist?(thisdirfile) then
		out_file = thisdirfile
	else
		@include_paths.each do |path|
			file = "#{path}/#{filename}"
			if FileTest.exist?(file) then
				out_file = file
				break
			end
		end
	end

	out_file ? Pathname.new(out_file).realpath.to_s : nil
end

def short_name(filename)
	tmp = filename.to_s
	@include_paths.each do |inc|
		tmp.slice!("#{inc}/")
	end
	tmp
end

def add_dependencies_to_array(filename, array)
	if (!array.include?( short_name(filename) )) then
		array.push short_name(filename)

		inFile = File.new(filename, "r")
		inFile.each do |line|
			thisFileIncludes = []
			if line.sub!(/^.*#include [<"](.*)[>"].*$/,'\1') then
				line.strip!
				incfile = find_file(line, File.dirname(filename))

				if incfile != nil then
					incpath = Pathname.new(incfile)
					thisFileIncludes << short_name(incpath.realpath)
					add_dependencies_to_array(incpath.realpath, array)
				else
					thisFileIncludes << line
				end
			end
			
			@includes[short_name(filename)] << thisFileIncludes
		end
	end
end

ARGV.each do |file|
	add_dependencies_to_array(Pathname.new(file).realpath, @scanned_files)
end

g = RGL::ImplicitGraph.new do |g|
	g.vertex_iterator do |b|
		@scanned_files.each do |f|
			b.call(f)
		end
	end

	g.adjacent_iterator do |f, b|
		@includes[f].uniq.select{|i|!i.empty?}.each(&b)
	end

	g.directed = true
end

g.write_to_graphic_file('svg', @output_filename)

