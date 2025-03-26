Gem::Specification.new do |s|
  s.name = 'rodish'
  s.version = '2.0.0'
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ["MIT-LICENSE"]
  s.rdoc_options += ["--quiet", "--line-numbers", "--inline-source", '--title', 'Rodish: Routing tree argv parser']
  s.license = "MIT"
  s.summary = "Routing tree argv parser"
  s.author = "Jeremy Evans"
  s.email = "code@jeremyevans.net"
  s.homepage = "https://rodish.jeremyevans.net/"
  s.files = %w(MIT-LICENSE) + Dir["lib/**/*.rb"]
  s.required_ruby_version = ">= 3.1"
  s.description = <<END
Rodish parses an argv array using a routing tree approach. It is
designed to make it easy to implement command line applications
that support multiple levels of subcommands, with options at each
level.
END
  s.metadata = {
    'bug_tracker_uri'   => 'https://github.com/jeremyevans/rodish/issues',
    'changelog_uri'     => 'https://github.com/jeremyevans/rodish/blob/master/CHANGELOG',
    'source_code_uri'   => 'https://github.com/jeremyevans/rodish',
  }

  s.add_dependency 'optparse'
  s.add_development_dependency 'minitest'
  s.add_development_dependency "minitest-global_expectations"
end
