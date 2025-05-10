require "rake/clean"

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
  sh({'COVERAGE'=>'1'}, "#{FileUtils::RUBY} test/rodish_test.rb")
end

desc "Run tests with method visibility checking"
task "test_vis" do
  sh({'CHECK_METHOD_VISIBILITY'=>'1'}, "#{FileUtils::RUBY} test/rodish_test.rb")
end

### RDoc

desc "Generate rdoc"
task :rdoc do
  rdoc_dir = "rdoc"
  rdoc_opts = ["--line-numbers", "--inline-source", '--title', 'Rodish: Routing tree argv parser']

  begin
    gem 'hanna'
    rdoc_opts.concat(['-f', 'hanna'])
  rescue Gem::LoadError
  end

  rdoc_opts.concat(['--main', 'README.rdoc', "-o", rdoc_dir] +
    %w"README.rdoc CHANGELOG MIT-LICENSE" +
    Dir["lib/**/*.rb"]
  )

  FileUtils.rm_rf(rdoc_dir)

  require "rdoc"
  RDoc::RDoc.new.document(rdoc_opts)
end
