require "rake/clean"
require "rdoc/task"

CLEAN.include ["rodish-*.gem", "rdoc", "coverage"]

### Specs

desc "Run tests"
task :default=>:test

desc "Run tests"
task :test do
  sh "#{FileUtils::RUBY} #{'-w' if RUBY_VERSION >= '3'} #{'-W:strict_unused_block' if RUBY_VERSION >= '3.4'} test/rodish_test.rb"
end

desc "Run tests with coverage"
task :test_cov do
  ENV['COVERAGE'] = '1'
  sh "#{FileUtils::RUBY} test/rodish_test.rb"
end

### RDoc

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.options += ["--quiet", "--line-numbers", "--inline-source", '--title', 'Rodish: Routing tree argv parser', '--main', 'README.rdoc']

  begin
    gem 'hanna'
    rdoc.options += ['-f', 'hanna']
  rescue Gem::LoadError
  end

  rdoc.rdoc_files.add %w"README.rdoc CHANGELOG MIT-LICENSE lib/**/*.rb"
end
