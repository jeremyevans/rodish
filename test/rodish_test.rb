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

gem 'minitest'
ENV['MT_NO_PLUGINS'] = '1' # Work around stupid autoloading of plugins
require 'minitest/global_expectations/autorun'

[true, false].each do |frozen|
  describe "Rodish#{" (frozen)" if frozen}" do
    attr_reader :app
    before do
      c = Class.new(Array)

      Rodish.processor(c) do
        options "example [options] [subcommand [subcommand_options] [...]]" do
          on("-v", "top verbose output")
          on("--version", "show program version") { halt "0.0.0" }
          on("--help", "show program help") { halt c.command.help }
        end

        before do
          push :top
        end

        on "a" do
          before do
            push :before_a
          end

          options "example a [options] [subcommand [subcommand_options] [...]]", key: :a do
            on("-v", "a verbose output")
          end

          on "b" do
            before do
              push :before_b
            end

            options "example a b [options] arg [...]", key: :b do
              on("-v", "b verbose output")
            end

            args(1...)

            run do |args, opts|
              push [:b, args, opts]
            end
          end

          args 2, invalid_args_message: "accepts: x y"
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
            wrap("Foo:", %w[bar baz quux options subcommand subcommand_options], limit: 23)
          end

          args(2...)

          is "j" do
            push :j
          end

          run_is "h" do |opts|
            push [:h, opts.dig(:g, :v), opts.dig(:g, :key)]
          end

          run_on "i" do
            before do |_, opts|
              push opts.dig(:g, :v)
              push opts.dig(:g, :key)
            end

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
          skip_option_parsing "example l"

          args(0...)

          on "m" do
            after_options do
              push [:m, :after_options]
            end

            before do
              push [:mb, :before]
            end

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
      app.process([]).must_equal [:top, :empty]
      app.process(%w[a b 1]).must_equal [:top, :before_a, :before_b, [:b, %w[1], {a: {}, b: {}}]]
      app.process(%w[a b 1 2]).must_equal [:top, :before_a, :before_b, [:b, %w[1 2], {a: {}, b: {}}]]
      app.process(%w[a 3 4]).must_equal [:top, :before_a, [:a, "3", "4"]]
      app.process(%w[c]).must_equal [:top, :c]
      app.process(%w[d 5]).must_equal [:top, [:d, "5"]]
      app.process(%w[e f]).must_equal [:top, :f]
    end

    it "supports run_on/run_is for subcommands dispatched to during run" do
      app.process(%w[g j]).must_equal [:top, :j]
      app.process(%w[g 1 h]).must_equal [:top, [:g, "1"], [:h, nil, nil]]
      app.process(%w[g 1 i]).must_equal [:top, [:g, "1"], nil, nil, :i]
      app.process(%w[g 1 i k]).must_equal [:top, [:g, "1"], nil, nil, :k]
    end

    it "supports post options for commands, parsed before subcommand dispatching" do
      app.process(%w[g 1 -v h]).must_equal [:top, [:g, "1"], [:h, true, nil]]
      app.process(%w[g 1 -v i]).must_equal [:top, [:g, "1"], true, nil, :i]
      app.process(%w[g 1 -v i k]).must_equal [:top, [:g, "1"], true, nil, :k]
      app.process(%w[g 1 -k 2 h]).must_equal [:top, [:g, "1"], [:h, nil, "2"]]
      app.process(%w[g 1 -k 2 i]).must_equal [:top, [:g, "1"], nil, "2", :i]
      app.process(%w[g 1 -k 2 i k]).must_equal [:top, [:g, "1"], nil, "2", :k]
    end

    it "supports skipping option parsing" do
      app.process(%w[l -A 1 b]).must_equal [:top, [:l, %w[-A 1 b]]]
    end

    it "handles invalid subcommands dispatched to during run" do
      proc{app.process(%w[g 1 l])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid post subcommand: l")
    end

    it "handles options at any level they are defined" do
      app.process(%w[-v a b -v 1 2]).must_equal [:top, :before_a, :before_b, [:b, %w[1 2], {a: {}, b: {v: true}, v: true}]]
      app.process(%w[a -v b 1 2]).must_equal [:top, :before_a, :before_b, [:b, %w[1 2], {a: {v: true}, b: {}}]]
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

    it "can get usages for all options" do
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
      usages["g"].must_equal <<~USAGE
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
        Foo: bar baz quux
             options subcommand
             subcommand_options
      USAGE
      usages["l"].must_equal <<~USAGE
        Usage:
            example l

        Commands:
            m    
      USAGE
    end

    next if frozen

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
        res.must_equal [:top, :before_a]
        proc{app.process(%w[a])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid arguments for a subcommand (accepts: x y)")
        res.must_equal [:top]
        proc{app.process(%w[a 1])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid arguments for a subcommand (accepts: x y)")
        res.must_equal [:top]
        proc{app.process(%w[a 1 2 3])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid arguments for a subcommand (accepts: x y)")
        res.must_equal [:top]
        proc{app.process(%w[c 1])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid number of arguments for c subcommand (accepts: 0, given: 1)")
        res.must_equal [:top]
        proc{app.process(%w[d])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid number of arguments for d subcommand (accepts: 1, given: 0)")
        res.must_equal [:top]
        proc{app.process(%w[d 1 2])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid number of arguments for d subcommand (accepts: 1, given: 2)")
        res.must_equal [:top]
        proc{app.process(%w[l m])}.must_raise(Rodish::CommandFailure).message.must_equal("no subcommand provided")
        res.must_equal [:top, [:m, :after_options]]
        proc{app.process(%w[l m n 1])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid number of arguments for l m n subcommand (accepts: 0, given: 1)")
        res.must_equal [:top, [:m, :after_options], [:mb, :before]]
      end

      it "raises CommandFailure for missing subcommand" do
        proc{app.process(%w[e])}.must_raise(Rodish::CommandFailure).message.must_equal("no subcommand provided")
        res.must_equal [:top]
      end

      it "raises CommandFailure for invalid subcommand" do
        proc{app.process(%w[e g])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid subcommand: g")
        res.must_equal [:top]

        app = Rodish.processor(Class.new) do
          on("f") {}
        end
        proc{app.process(%w[g])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid subcommand: g")
      end

      it "raises CommandFailure for unexpected options" do
        proc{app.process(%w[-d])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid option: -d")
        res.must_be_empty
        proc{app.process(%w[a -d])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid option: -d")
        res.must_equal [:top]
        proc{app.process(%w[a b -d])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid option: -d")
        res.must_equal [:top, :before_a]
        proc{app.process(%w[d -d 1 2])}.must_raise(Rodish::CommandFailure).message.must_equal("invalid option: -d")
        res.must_equal [:top]
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
        res.must_equal [:top, [:z, "h"]]

        app.on("z", "y") do
          run do
            push :y
          end
        end
        app.process(%w[z y])
        res.must_equal [:top, :y]

        app.is("z", "y", "x", args: 1) do |arg|
          push [:x, arg]
        end
        app.process(%w[z y x j])
        res.must_equal [:top, [:x, "j"]]
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
        res.must_equal [:top, :m]

        app.process(%w[k 1 o])
        res.must_equal [:top, [:k, "1"], :o]

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
