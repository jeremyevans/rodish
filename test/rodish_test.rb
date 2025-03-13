# frozen_string_literal: true

if ENV.delete('COVERAGE')
  require 'simplecov'

  SimpleCov.start do
    enable_coverage :branch
    add_filter "/test/"
    add_group('Missing'){|src| src.covered_percent < 100}
    add_group('Covered'){|src| src.covered_percent == 100}
  end
end

require_relative "../lib/rodish"
$:.unshift(File.expand_path(File.join(__dir__, "../lib")))

gem 'minitest'
ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
require 'minitest/global_expectations/autorun'

[true, false].each do |frozen|
  describe "Rodish#{" (frozen)" if frozen}" do
    attr_reader :app
    before do
      c = Class.new(Array)
      Rodish.processor(c)
      c.plugin :post_commands
      c.on do
        options "example [options] [subcommand [subcommand_options] [...]]" do
          on("-v", "top verbose output")
          on("--version", "show program version") { halt "0.0.0" }
          on("--help", "show program help") { halt c.command.help }
        end

        on "a" do
          options "example a [options] [subcommand [subcommand_options] [...]]", key: :a do
            on("-v", "a verbose output")
          end

          on "b" do
            options "example a b [options] arg [...]", key: :b do
              on("-v", "b verbose output")
            end

            args(1...)

            run do |args, opts|
              push [:b, args, opts]
            end
          end

          args 2
          run do |x, y|
            push [:a, x, y]
          end
        end

        is "c" do
          push :c
        end

        is "d", args: 1 do |d|
          push [:d, d]
        end

        on "e" do
          on "f" do
            run do
              push :f
            end
          end
        end

        on "g" do
          post_options "example g arg [options] [subcommand [subcommand_options] [...]]", key: :g do
            on("-v", "g verbose output")
            on("-k", "--key=foo", "set key")
          end

          args(2...)

          is "j" do
            push :j
          end

          run_is "h" do |opts|
            push [:h, opts.dig(:g, :v), opts.dig(:g, :key)]
          end

          run_on "i" do
            is "k" do
              push :k
            end

            run do
              push :i
            end
          end

          run do |(x, *argv), opts, command|
            push [:g, x]
            command.run(self, opts, argv)
          end
        end

        on "l" do
          banner "example l"

          args(0...)

          on "m" do
            is "n" do
              push :n
            end
          end

          run do |argv|
            push [:l, argv]
          end
        end

        run do
          push :empty
        end
      end

      c.freeze if frozen
      @app = c
    end

    it "executes expected command code in expected order" do
      app.process([]).must_equal [:empty]
      app.process(%w[a b 1]).must_equal [[:b, %w[1], {a: {}, b: {}}]]
      app.process(%w[a b 1 2]).must_equal [[:b, %w[1 2], {a: {}, b: {}}]]
      app.process(%w[a 3 4]).must_equal [[:a, "3", "4"]]
      app.process(%w[c]).must_equal [:c]
      app.process(%w[d 5]).must_equal [[:d, "5"]]
      app.process(%w[e f]).must_equal [:f]
    end

    it "supports run_on/run_is for subcommands dispatched to during run" do
      app.process(%w[g j]).must_equal [:j]
      app.process(%w[g 1 h]).must_equal [[:g, "1"], [:h, nil, nil]]
      app.process(%w[g 1 i]).must_equal [[:g, "1"], :i]
      app.process(%w[g 1 i k]).must_equal [[:g, "1"], :k]
    end

    it "supports post options for commands, parsed before subcommand dispatching" do
      app.process(%w[g 1 -v h]).must_equal [[:g, "1"], [:h, true, nil]]
      app.process(%w[g 1 -v i]).must_equal [[:g, "1"], :i]
      app.process(%w[g 1 -v i k]).must_equal [[:g, "1"], :k]
      app.process(%w[g 1 -k 2 h]).must_equal [[:g, "1"], [:h, nil, "2"]]
      app.process(%w[g 1 -k 2 i]).must_equal [[:g, "1"], :i]
      app.process(%w[g 1 -k 2 i k]).must_equal [[:g, "1"], :k]
    end

    it "handles invalid subcommands dispatched to during run" do
      proc{app.process(%w[g 1 l])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid post subcommand: l")
    end

    it "handles options at any level they are defined" do
      app.process(%w[-v a b -v 1 2]).must_equal [[:b, %w[1 2], {a: {}, b: {v: true}, v: true}]]
      app.process(%w[a -v b 1 2]).must_equal [[:b, %w[1 2], {a: {v: true}, b: {}}]]
    end

    it "raises CommandFailure when there a command has no command block or subcommands" do
      app = Rodish.processor(Class.new) {}
      proc{app.process([])}.must_raise(Rodish::CommandFailure).message.must_equal("program bug, no run block or subcommands defined for command")
      app = Rodish.processor(Class.new) do
        on("f") {}
      end
      proc{app.process(%w[f])}.must_raise(Rodish::CommandFailure).message.must_equal("program bug, no run block or subcommands defined for f subcommand")
    end

    it "raises CommandFailure for unexpected post options" do
      proc{app.process(%w[g 1 -b h])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid option: -b")
    end

    it "raises CommandExit for blocks that use halt" do
      proc{app.process(%w[--version])}.must_raise(Rodish::CommandExit).message.must_equal("0.0.0")
      proc{app.process(%w[--help])}.must_raise(Rodish::CommandExit).message.must_equal(<<~USAGE)
        Usage:
            example [options] [subcommand [subcommand_options] [...]]

        Commands:
            a    
            c    
            d    
            e    
            g    
            l    

        Options:
            -v                               top verbose output
                --version                    show program version
                --help                       show program help
      USAGE
    end

    it "CommandExit#failure? returns false" do
      begin
        app.process(%w[--version])
      rescue Rodish::CommandExit => e
      end

      e.failure?.must_equal false
    end

    it "CommandFailure#failure? returns true" do
      begin
        app.process(%w[--bad])
      rescue Rodish::CommandFailure => e
      end

      e.failure?.must_equal true
    end

    it "CommandFailure#message_with_usage returns the error message and usage/options for the related command" do
      begin
        app.process(%w[--bad])
      rescue Rodish::CommandFailure => e
      end

      e.message_with_usage.must_equal <<~USAGE
        invalid option: --bad

        Usage:
            example [options] [subcommand [subcommand_options] [...]]

        Commands:
            a    
            c    
            d    
            e    
            g    
            l    

        Options:
            -v                               top verbose output
                --version                    show program version
                --help                       show program help
      USAGE
    end

    it "CommandFailure#message_with_usage returns only the error message if there is no usage/options for the related command" do
      app = Class.new(Array)
      Rodish.processor(app){run{}}

      begin
        app.process(%w[--bad])
      rescue Rodish::CommandFailure => e
      end

      e.message_with_usage.must_equal "invalid option: --bad"
    end

    it "#subcommand returns the related subcommand" do
      app.command.subcommand("d").command_path.must_equal ["d"]
    end

    it "#post_subcommand returns the related post subcommand" do
      app.command.subcommand("g").post_subcommand("h").command_path.must_equal %w"g h"
    end

    next if frozen

    it "skip_option_parsing plugin supports skipping option parsing" do
      app.plugin :skip_option_parsing
      app.on("l").options("example l 1"){}
      app.command.subcommand("l").help.must_equal <<~USAGE
        Usage:
            example l 1

        Commands:
            m    

        Options:
      USAGE
      app.on("l").skip_option_parsing "example l 2"
      app.process(%w[l -A 1 b]).must_equal [[:l, %w[-A 1 b]]]
      app.command.subcommand("l").help.must_equal <<~USAGE
        Usage:
            example l 2

        Commands:
            m    
      USAGE
    end

    it "supports cache_help_output plugin for caching and freezing help output" do
      cmd = app.command.subcommand("a")
      cmd.help.wont_be_same_as cmd.help
      app.plugin :cache_help_output
      app.freeze
      cmd.help.must_be_same_as cmd.help
    end

    it "supports help_examples plugin to set the order of help sections" do
      app.plugin :help_examples
      app.command.subcommand("a").help.must_equal <<~USAGE
        Usage:
            example a [options] [subcommand [subcommand_options] [...]]

        Commands:
            b    

        Options:
            -v                               a verbose output
      USAGE

      app.on("a").help_example "foo"
      app.command.subcommand("a").help.must_equal <<~USAGE
        Usage:
            example a [options] [subcommand [subcommand_options] [...]]

        Commands:
            b    

        Options:
            -v                               a verbose output

        Examples:
            foo
      USAGE

      app.plugin :help_order
      app.on("a").help_order(:examples, :commands)
      app.on("a").help_example "bar"
      app.command.subcommand("a").help.must_equal <<~USAGE
        Examples:
            foo
            bar

        Commands:
            b    
      USAGE
    end

    it "supports help_order to set the order of help sections" do
      app.plugin :help_order
      app.on("a").help_order(:options, :commands)
      app.command.subcommand("a").help.must_equal <<~USAGE
        Options:
            -v                               a verbose output

        Commands:
            b    
      USAGE
    end

    it "supports default_help_order plugin to set the order of help sections for all commands" do
      app.plugin :help_order, default_help_order: [:options, :commands]
      cmd = app.command.subcommand("a")
      cmd.help.must_equal <<~USAGE
        Options:
            -v                               a verbose output

        Commands:
            b    
      USAGE

      app.on("a").help_order(:commands)
      cmd.help.must_equal <<~USAGE
        Commands:
            b    
      USAGE
    end

    it "help_options_values plugin supports showing allowed help options" do
      app.plugin :help_option_values
      app.on("g").help_option_values("Foo:", %w[bar baz quux options subcommand subcommand_options])
      app.command.subcommand("g").help.must_equal <<~USAGE
          Usage:
              example g arg [options] [subcommand [subcommand_options] [...]]

          Commands:
              j    

          Post Commands:
              h    
              i    

          Post Options:
              -v                               g verbose output
              -k, --key=foo                    set key

          Allowed Option Values:
              Foo: bar baz quux options subcommand subcommand_options
      USAGE
    end

    it "help_options_values plugin supports context-sensitive allowed help options" do
      app.plugin :help_option_values
      app.plugin :help_order
      app.on("g").help_order(:option_values)
      cmd = app.command.subcommand("g")

      cmd.context_help([]).must_equal ""

      app.on("g").help_option_values("Foo:"){empty? ? %w[bar baz quux options] : %w[subcommand subcommand_options]}
      cmd.context_help([]).must_equal <<~USAGE
          Allowed Option Values:
              Foo: bar baz quux options
      USAGE
      cmd.context_help([1]).must_equal <<~USAGE
          Allowed Option Values:
              Foo: subcommand subcommand_options
      USAGE
    end

    it "wrapped_options_separator plugin adds wrap to option parser, for wrapping long separator lines" do
      app.plugin :wrapped_options_separator
      cmd = app.command.subcommand("g")
      cmd.post_option_parser.wrap("Foo:", %w[bar baz quux options subcommand subcommand_options], limit: 23)
      cmd.post_option_parser.summarize(String.new).must_equal <<~USAGE
            -v                               g verbose output
            -k, --key=foo                    set key
        Foo: bar baz quux
             options subcommand
             subcommand_options
      USAGE
    end

    it "usages plugin allows getting usages for all options" do
      app.plugin :usages
      usages = app.usages
      usages.keys.sort.must_equal [
        "",
        "a",
        "a b",
        "c",
        "d",
        "e",
        "e f",
        "g",
        "g h",
        "g i",
        "g i k",
        "g j",
        "l",
        "l m",
        "l m n"
      ]

      usages[""].must_equal <<~USAGE
        Usage:
            example [options] [subcommand [subcommand_options] [...]]

        Commands:
            a    
            c    
            d    
            e    
            g    
            l    

        Options:
            -v                               top verbose output
                --version                    show program version
                --help                       show program help
      USAGE
      usages["a"].must_equal <<~USAGE
        Usage:
            example a [options] [subcommand [subcommand_options] [...]]

        Commands:
            b    

        Options:
            -v                               a verbose output
      USAGE
      usages["a b"].must_equal <<~USAGE
        Usage:
            example a b [options] arg [...]

        Options:
            -v                               b verbose output
      USAGE
      usages["l"].must_equal <<~USAGE
        Usage:
            example l

        Commands:
            m    
      USAGE
    end

    it "supports loading plugins before configuring root command" do
      c = Class.new(Array)
      Rodish.processor(c)
      c.plugin :usages
      c.usages.must_equal({""=>""})
    end

    it "raises for invalid plugin argument" do
      proc{app.plugin("usages")}.must_raise(ArgumentError).message.must_equal('invalid argument to plugin: "usages"')
    end

    it "raises if plugin file exists but plugin does not register itself after loading it" do
      mod = Module.new{def fetch(_); end}
      Rodish::Plugins.singleton_class.prepend(mod)
      proc{app.plugin(:usages)}.must_raise(RuntimeError).message.must_equal('rodish plugin did not properly register itself: :usages')
    ensure
      mod.send(:remove_method, :fetch)
    end

    it "correctly handles case where plugin module loads plugin" do
      called = false
      mod = Module.new{define_method(:fetch){|name| called ? super(name) : (called = true; nil)}}
      Rodish::Plugins.singleton_class.prepend(mod)
      app.plugin(:usages)
      app.usages.must_be_kind_of(Hash)
    ensure
      mod.send(:remove_method, :fetch)
    end

    it "supports empty plugin modules" do
      app.plugin(Module.new{})
      app.process([]).must_equal [:empty]
    end

    it "runs before_load and after_load plugin methods when loading plugins" do
      b = proc{}
      res = []
      app.plugin(Module.new do
        define_singleton_method(:before_load) do |app, *a, **kw, &b|
          res << [:before, app, a, kw, b]
        end
        define_singleton_method(:after_load) do |app, *a, **kw, &b|
          res << [:after, app, a, kw, b]
        end
      end, 1, kw: 1, &b)
      res.must_equal [[:before, app, [1], {kw: 1}, b], [:after, app, [1], {kw: 1}, b]]
      app.process([]).must_equal [:empty]
    end

    it "supports ProcessorMethods module in plugins" do
      app.plugin(Module.new{self::ProcessorMethods = Module.new{def foo; :bar; end}})
      app.foo.must_equal :bar
    end

    it "supports DSLMethods module in plugins" do
      app.plugin(Module.new{self::DSLMethods = Module.new{def foo; :bar; end}})
      app.on("l").foo.must_equal :bar
    end

    it "supports CommandMethods module in plugins" do
      app.plugin(Module.new{self::CommandMethods = Module.new{def foo; :bar; end}})
      app.command.subcommand("l").foo.must_equal :bar
    end

    it "supports OptionParserMethods module in plugins" do
      app.plugin(Module.new{self::OptionParserMethods = Module.new{def version; on("-v"){halt "vv"}; end}})
      app.on("c").options("x"){version}
      proc{app.process(["c", "-v"])}.must_raise(Rodish::CommandExit).message.must_equal("vv")
    end

    describe "failure handling" do
      attr_reader :res

      before do
        @res = res = []
        app.define_singleton_method(:new) { res.clear }
      end

      it "raises CommandFailure for unexpected number of arguments without executing code" do
        proc{app.process(%w[6])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid number of arguments for command (accepts: 0, given: 1)")
        res.must_be_empty
        proc{app.process(%w[a b])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid number of arguments for a b subcommand (accepts: 1..., given: 0)")
        res.must_equal []
        proc{app.process(%w[c 1])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid number of arguments for c subcommand (accepts: 0, given: 1)")
        res.must_equal []
        proc{app.process(%w[d])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid number of arguments for d subcommand (accepts: 1, given: 0)")
        res.must_equal []
        proc{app.process(%w[d 1 2])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid number of arguments for d subcommand (accepts: 1, given: 2)")
        res.must_equal []
      end

      it "invalid_args_message plugin supports customizing the invalid args message via #args" do
        app.plugin :invalid_args_message
        proc{app.process(%w[a])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid number of arguments for a subcommand (accepts: 2, given: 0)")

        app.on("a").args(2, invalid_args_message: "accepts: x y")
        proc{app.process(%w[a])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid arguments for a subcommand (accepts: x y)")
        res.must_equal []
        proc{app.process(%w[a 1])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid arguments for a subcommand (accepts: x y)")
        res.must_equal []
        proc{app.process(%w[a 1 2 3])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid arguments for a subcommand (accepts: x y)")
        res.must_equal []
      end

      it "invalid_args_message plugin supports customizing the invalid args message via #is" do
        app.plugin :invalid_args_message
        app.is("a", args: 2, invalid_args_message: "accepts: x y"){}
        proc{app.process(%w[a])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid arguments for a subcommand (accepts: x y)")
        res.must_equal []
      end

      it "invalid_args_message plugin supports customizing the invalid args message via #run_is" do
        app.plugin :invalid_args_message
        app.on("g").run_is("w", args: 2, invalid_args_message: "accepts: x y"){}
        proc{app.process(%w[g 1 w])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid arguments for g w subcommand (accepts: x y)")
        res.must_equal [[:g, "1"]]
      end

      it "after_options_hook plugin should support an after_options hook" do
        app.plugin :after_options_hook
        app.on("l", "m").after_options do
          push [:m, :after_options]
        end
        proc{app.process(%w[l m])}.must_raise(Rodish::CommandFailure).message.must_equal("no subcommand provided")
        res.must_equal [[:m, :after_options]]
        proc{app.process(%w[l m n 1])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid number of arguments for l m n subcommand (accepts: 0, given: 1)")
        res.must_equal [[:m, :after_options]]
      end

      it "raises CommandFailure for missing subcommand" do
        proc{app.process(%w[e])}.must_raise(Rodish::CommandFailure).message.must_equal("no subcommand provided")
        res.must_equal []
      end

      it "raises CommandFailure for invalid subcommand" do
        proc{app.process(%w[e g])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid subcommand: g")
        res.must_equal []

        app = Rodish.processor(Class.new) do
          on("f") {}
        end
        proc{app.process(%w[g])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid subcommand: g")
      end

      it "raises CommandFailure for unexpected options" do
        proc{app.process(%w[-d])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid option: -d")
        res.must_be_empty
        proc{app.process(%w[a -d])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid option: -d")
        res.must_equal []
        proc{app.process(%w[a b -d])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid option: -d")
        res.must_equal []
        proc{app.process(%w[d -d 1 2])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid option: -d")
        res.must_equal []
      end

      it "CommandFailure#message_with_usage handles cases where no command is present" do
        proc{raise Rodish::CommandFailure, "foo"}.must_raise(Rodish::CommandFailure).message_with_usage.must_equal("foo")
      end

      it "supports adding subcommands after initialization" do
        proc{app.process(%w[z])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid number of arguments for command (accepts: 0, given: 1)")
        res.must_be_empty

        app.on("z") do
          args 1
          run do |arg|
            push [:z, arg]
          end
        end
        app.process(%w[z h])
        res.must_equal [[:z, "h"]]

        app.on("z", "y") do
          run do
            push :y
          end
        end
        app.process(%w[z y])
        res.must_equal [:y]

        app.is("z", "y", "x", args: 1) do |arg|
          push [:x, arg]
        end
        app.process(%w[z y x j])
        res.must_equal [[:x, "j"]]
      end

      it "supports autoloading" do
        main = TOPLEVEL_BINDING.receiver
        main.instance_variable_set(:@ExampleRodish, app)
        app.on("k") do
          autoload_subcommand_dir("test/rodish-example")
          autoload_post_subcommand_dir("test/rodish-example-post")

          args(2...)
          run do |(x, *argv), opts, command|
            push [:k, x]
            command.run(self, opts, argv)
          end
        end

        app.process(%w[k m])
        res.must_equal [:m]

        app.process(%w[k 1 o])
        res.must_equal [[:k, "1"], :o]

        proc{app.process(%w[k n])}.must_raise(Rodish::CommandFailure).message.must_equal("program bug, autoload of subcommand n failed")
      ensure
        main.remove_instance_variable(:@ExampleRodish)
      end
    end

    it "includes command descriptions in output if present" do
      subcommands = %w[a b c d e f g]
      app.on("z") do
        desc "Trivial Example"
        banner "example z command"
        post_banner "example z arg post-command"
        subcommands.each do |cmd|
          is(cmd) {}
        end
        on("d") do
          desc "D-DESC"
        end

        run_on("h1") do
          desc "H1-DESC"
          run{}
        end
      end
      app.command.subcommand("z").help.must_equal <<~USAGE
        Trivial Example

        Usage:
            example z command
            example z arg post-command

        Commands:
            a     
            b     
            c     
            d     D-DESC
            e     
            f     
            g     

        Post Commands:
            h1    H1-DESC
      USAGE
    end
  end
end
