require 'rubygems'
require 'rake'

begin
  require 'spec/rake/spectask'
  Spec::Rake::SpecTask.new(:spec => :check_dependencies) do |spec|
    spec.libs << 'lib' << 'spec'
    spec.spec_files = FileList['spec/**/*_spec.rb']
  end

  Spec::Rake::SpecTask.new(:rcov) do |spec|
    spec.libs << 'lib' << 'spec'
    spec.pattern = 'spec/**/*_spec.rb'
    spec.rcov = true
    spec.rcov_opts = ['--exclude', '.rvm']
  end
rescue LoadError
  task :spec do
    abort "Rspec is not available. In order to run specs, you must: sudo gem install rspec"
  end
end

begin
  permutations = {
    'fakeweb' => %w( net/http ),
    'webmock' => %w( net/http httpclient patron em-http )
  }

  require 'cucumber/rake/task'
  namespace :features do
    permutations.each do |http_stubbing_adapter, http_libraries|
      features_subtasks = []

      namespace http_stubbing_adapter do
        http_libraries.each do |http_lib|
          next if RUBY_PLATFORM =~ /java/ && %w( patron em-http ).include?(http_lib)

          sanitized_http_lib = http_lib.gsub('/', '_')
          features_subtasks << "features:#{http_stubbing_adapter}:#{sanitized_http_lib}"

          task "#{sanitized_http_lib}_prep" => :check_dependencies do
            ENV['HTTP_STUBBING_ADAPTER'] = http_stubbing_adapter
            ENV['HTTP_LIB'] = http_lib
          end

          Cucumber::Rake::Task.new(
            { sanitized_http_lib => "#{features_subtasks.last}_prep" },
            "Run the features using #{http_stubbing_adapter} and #{http_lib}") do |t|
              t.cucumber_opts = ['--format', 'progress', '--tags', "@all_http_libs,@#{sanitized_http_lib}"]

              # disable scenarios on heroku that can't pass due to heroku's restrictions
              t.cucumber_opts += ['--tags', '~@spawns_localhost_server'] if ENV.keys.include?('HEROKU_SLUG')
          end
        end
      end

      desc "Run the features using #{http_stubbing_adapter} and each of #{http_stubbing_adapter}'s supported http libraries"
      task http_stubbing_adapter => features_subtasks
    end
  end

  desc "Run the features using each supported permutation of http stubbing library and http library."
  task :features => permutations.keys.map { |a| "features:#{a}" }
rescue LoadError
  task :features do
    abort "Cucumber is not available. In order to run features, you must: sudo gem install cucumber"
  end
end

task :default => [:spec, :features]

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "vcr #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

def gemspec
  @gemspec ||= begin
    file = File.expand_path('../vcr.gemspec', __FILE__)
    eval(File.read(file), binding, file)
  end
end

# This is borrowed from jeweler:
# http://github.com/technicalpickles/jeweler/blob/v1.4.0/lib/jeweler/commands/check_dependencies.rb#L10-31
task :check_dependencies do
  requirement_method = nil
  required_dependencies = gemspec.dependencies

  # ignore libraries that can't be installed on jruby
  if RUBY_PLATFORM =~ /java/
    required_dependencies.reject! { |d| %w( patron em-http-request ).include?(d.name) }
  end

  missing_dependencies = required_dependencies.select do |dependency|
    requirement_method = [:requirement?, :version_requirements].detect { |m| dependency.respond_to?(m) }
    begin
      Gem.activate dependency.name, dependency.send(requirement_method).to_s
      false
    rescue LoadError => e
      true
    end
  end

  if missing_dependencies.empty?
    puts "All dependencies seem to be installed."
  else
    puts "Missing some dependencies. Install them with the following commands:"
    missing_dependencies.each do |dependency|
      puts %Q{\tgem install #{dependency.name} --version "#{dependency.send(requirement_method)}"}
    end

    abort "Run the specified gem commands before trying to run this again: #{$0} #{ARGV.join(' ')}"
  end
end

begin
  require 'rake/gempackagetask'
rescue LoadError
  task(:gem) { $stderr.puts '`gem install rake` to package gems' }
else
  Rake::GemPackageTask.new(gemspec) do |pkg|
    pkg.gem_spec = gemspec
  end
  task :gem => :gemspec
end

desc "install the gem locally"
task :install => :package do
  sh %{gem install pkg/#{gemspec.name}-#{gemspec.version}}
end

desc "validate the gemspec"
task :gemspec do
  gemspec.validate
end

task :package => :gemspec
