# encoding: utf-8
class Language

  @eval_path = File.dirname(__FILE__)

  # Public: A Hash containing every language that we support (sans special
  #         cases which are in rublets.rb itself), which includes information
  #         about how to evaluate the language.
  #
  # !!! PLEASE KEEP THIS LIST ALPHABETICAL !!!
  # !!! PLEASE KEEP THIS LIST ALPHABETICAL !!!
  # !!! PLEASE KEEP THIS LIST ALPHABETICAL !!!
  #
  # Returns a large Hash of Hashes which explains how to run an evaluation
  #   and contains necessary metadata for doing so.
  @languages = {
    'apricot' => {
      :aliases              => ['apr'],
      :evaluate_with        => ['/usr/local/rvm/bin/rvm',
        'rbx', 'do', 'rbx',
        '-I/opt/rublets/apricot-lang/apricot/lib', '-rapricot'
      ],
      :alter_code           => lambda { |code|
        "begin
  puts \"=> \" + Apricot::Compiler.eval(#{code.inspect}).apricot_inspect
rescue Exception => e
  puts \"\#{e.class}: \#{e.message}\"
end"
      },
      :version_lambda       => lambda {
        Dir.chdir('/opt/rublets/apricot-lang/apricot') do
          `git log --format='%h - %cD' -1`
        end
      },
      :extension            => 'rb',
      :timeout              => 10,
    },
    'arroyo' => {
      :evaluate_with        => ['arroyo'],
      :extension            => 'arr',
      :before               => 'print (',
      :after                => ')',
    },
    'bash' => {
      :aliases              => ['$'],
      :evaluate_with        => ['bash'],
      :extension            => 'sh',
    },
    'befunge' => {
      :evaluate_with        => ['befrunge'],
      :extension            => 'bf',
    },
    'brainfuck' => {
      :evaluate_with        => ['bf.rb'],
      :aliases              => ['bf'],
      :extension            => 'b',
    },
    'c' => {
      :evaluate_with        => ['bash', 'run-c.sh'],
      :binaries_must_exist  => ['gcc', 'bash'],
      :version_against      => '/usr/bin/gcc',
      :extension            => 'c',
      :required_files       => {"#{@eval_path}/run-c.sh" => 'run-c.sh',
        "#{@eval_path}/rublets-c.h" => 'stdinc.h',
      },
      :before               => "#include \"stdinc.h\"\n",
    },
    'c#' => {
      :aliases              => ['csharp', 'cs'],
      :evaluate_with        => ['csharp'],
      :extension            => 'cs',
      :code_from_stdin      => true,
      :alter_code           => lambda { |code|
        code.end_with?(';') ? code : "#{code};"
      },
    },
    'c++' => {
      :evaluate_with        => ['bash', 'run-cpp.sh'],
      :binaries_must_exist  => ['g++', 'bash'],
      :version_against      => '/usr/bin/gcc',
      :extension            => 'cpp',
      :required_files       => {"#{@eval_path}/run-cpp.sh" => 'run-cpp.sh'},
      :before               => File.read("#{@eval_path}/rublets-cpp.h"),
    },
    'ceylon' => {
      :evaluate_with        => ['bash', 'run-ceylon.sh'],
      :binaries_must_exist  => ['ceylonc', 'ceylon', 'bash'],
      :extension            => 'ceylon',
      :required_files       => {"#{@eval_path}/run-ceylon.sh" => 'run-ceylon.sh'},
    },
    'chicken' => {
      :aliases              => ['scheme'],
      :evaluate_with        => ['xargs', '-0', 'csi', '-p'],
      :extension            => 'scm',
      :binaries_must_exist  => ['csi'],
      :code_from_stdin      => true,
    },
    'clay' => {
      :evaluate_with        => ['clay', '-run'],
      :extension            => 'clay',
    },
    'clisp' => {
      :evaluate_with        => ['clisp', '-q'],
      :extension            => 'lisp',
      :code_from_stdin      => true,
      :skip_preceding_lines => 1,
    },
    'clojure' => {
      :aliases              => ['clj'],
      :evaluate_with        => ['xargs', '-0', 'clojure', '-e'],
      :binaries_must_exist  => ['clojure'],
      :code_from_stdin      => true,
      :extension            => 'clj',
      :timeout              => 10,
    },
    'coq' => {
      :evaluate_with        => ['coqc', '-color', 'no'],
      :extension            => 'v',
      :script_filename      => 'rublets.v',
      :output_limit         => 4,
      :alter_result         => lambda { |result|
        v = result.gsub(/\e\[(\d\d);\d\d;\d\d;\d\d;\d\d;\d\dm/, "\e[\\1m")
        v.split("\n")
          .select { |line| !line.start_with? '<W> Grammar extension: ' }
          .join("\n")
      },
    },
    'elixir' => {
      :evaluate_with        => ['elixir'],
      :extension            => 'exs',
      :alter_code           => lambda { |code|
        eval_code = code.inspect
        "{r, _} = Code.eval_string(#{eval_code}, []); IO.puts inspect(r)"
      },
    },
    'elm' => {
      :evaluate_with        => [
        'elm',
        '-r',
        'http://elrod.me/elm-runtime.js'
      ],
      :extension            => 'elm',
      :unsafe_perform_after => lambda { |exitcode, home|
        return if exitcode != 0
        begin
          uri = URI.parse('http://www.htmlfish.me/')
          http = Net::HTTP.new(uri.host, uri.port)

          response = http.post(
            uri.path,
            URI.encode_www_form({'html' => File.open(Dir[home + '/*.html'][0]).read}))
        end
        return response.body
      },
    },
    'erlang' => {
      :aliases              => ['erl'],
      :evaluate_with        => ['erl'],
      :extension            => 'erl',
      :skip_preceding_lines => 1,
      :skip_ending_lines    => 1,
      :code_from_stdin      => true,
      :alter_result         => lambda { |result|
        result.gsub(/^\d+> /, '')
      },
    },
    'f#' => {
      :aliases              => ['fsharp'],
      :evaluate_with        => ['fsharpi', '--nologo'],
      :code_from_stdin      => true,
      :extension            => 'fs',
      :alter_code           => lambda { |code|
        code + ' #quit;;'
      },
      :alter_result         => lambda { |result|
        lines = result.split("\n")
        lines[0].gsub!(/^> /, '')
        lines.join("\n")
      },
      :skip_preceding_lines => 1,
      :skip_ending_lines    => 2,
    },
    'factor' => {
      :evaluate_with        => ['factor-vm', 'factorhack.factor'],
      :code_from_stdin      => true,
      :extension            => 'factor',
      :required_files       => {"#{@eval_path}/factorhack.factor" => 'factorhack.factor'},
    },
    'forth' => {
      :evaluate_with        => ['gforth'],
      :extension            => 'forth',
      :after                => ' bye',
    },
    'frink' => {
      :evaluate_with        => [
        'java', '-cp', '/usr/share/java/frink.jar', 'frink.parser.Frink'
      ] + (File.exists?('/etc/frink/units.txt') ? ['-u', '/etc/frink/units.txt'] : []),
      :version_against      => '/usr/share/java/frink.jar',
      :timeout              => 6,
      :extension            => 'frink',
      :code_from_stdin      => true,
      :skip_preceding_lines => 1,
      :skip_ending_lines    => 1,
    },
    'go' => {
      :evaluate_with        => ['go', 'run'],
      :extension            => 'go',
      :before               => [
        'package main',
        'import "fmt"',
      ].join("\n") + "\n",
    },
    'golfscript' => {
      :evaluate_with        => ['golfscript'],
      :extension            => 'golfscript',
    },
    'groovy' => {
      :evaluate_with        => ['groovysh'],
      :binaries_must_exist  => ['groovysh', 'groovy'],
      :extension            => 'groovy',
      :skip_preceding_lines => 6,
      :skip_ending_lines    => 1,
      :code_from_stdin      => true,
    },
    'haskell' => {
      :evaluate_with        => ['ghci', '-v0'],
      :extension            => 'hs',
      :code_from_stdin      => true,
      :required_files       => {"#{@eval_path}/ghci" => '.ghci'},
      :required_files_perms => 0640,
    },
    'idris' => {
      :evaluate_with        => ['idris', '--quiet'],
      :extension            => 'idr',
      :code_from_stdin      => true,
    },
    'io' => {
      :evaluate_with        => ['io'],
      :extension            => 'io',
    },
    'j' => {
      :evaluate_with        => ['j-language'],
      :extension            => 'ijs',
      :code_from_stdin      => true,
      :skip_ending_lines    => 1,
      :alter_result         => lambda { |result| result.lstrip },
    },
    'java' => {
      :evaluate_with        => ['bash', 'run-java.sh', 'default'],
      :version_against      => '/usr/lib/jvm/java-1.7.0/bin/javac',
      :binaries_must_exist  => ['javac', 'java', 'bash'],
      :extension            => 'java',
      :required_files       => {"#{@eval_path}/run-java.sh" => 'run-java.sh'},
      :script_filename      => 'Rublets.java',
      :alter_code           => lambda { |code|
        return code if code.include? 'class Rublets'
        return "public class Rublets { #{code} }"
      },
    },
     'java18' => {
      :aliases              => ['java8'],
      :evaluate_with        => ['bash', 'run-java.sh', '1.8'],
      :version_against      => '/usr/lib/jvm/java-1.8.0/bin/javac',
      :binaries_must_exist  => ['/usr/lib/jvm/java-1.8.0/bin/javac', '/usr/lib/jvm/java-1.8.0/bin/java', 'bash'],
      :extension            => 'java',
      :required_files       => {"#{@eval_path}/run-java.sh" => 'run-java.sh'},
      :script_filename      => 'Rublets.java',
      :alter_code           => lambda { |code|
        return code if code.include? 'class Rublets'
        return "public class Rublets { #{code} }"
      },
    },
   'javascript' => {
      :aliases              => ['js'],
      :evaluate_with        => ['js', '-i'],
      :extension            => 'js',
      :code_from_stdin      => true,
    },
    'kawa' => {
      :evaluate_with        => ['kawa', '-s'],
      :extension            => 'scm',
      :code_from_stdin      => true,
      :alter_result         => lambda { |result|
        result.gsub(/^#\|kawa:\d+\|# /, '')
      },
    },
   'lolcode' => {
      :evaluate_with        => ['lol-pl'],
      :extension            => 'lol',
      :alter_code           => lambda { |code|
        code.gsub(';;', "\n")
      },
    },
    'lua' => {
      :evaluate_with        => ['lua', '-i'],
      :extension            => 'lua',
      :skip_preceding_lines => 2,
      :skip_ending_lines    => 1,
      :code_from_stdin      => true,
    },
    'maxima' => {
      :evaluate_with        => [
        'maxima',
        '--very-quiet', '--disable-readline'
      ],
      :extension            => 'maxima',
      :code_from_stdin      => true,
      :alter_code           => lambda { |code|
        "display2d: false$ leftjust: true$ #{code}#{";" unless (code.end_with?(';') || code.end_with?('$'))}"
      },
    },
    'node' => {
      :aliases              => ['nodejs'],
      :evaluate_with        => ['node', '-p'],
      :code_from_stdin      => true,
      :extension            => 'js',
    },
    'objective-c' => {
      :aliases              => ['obj-c'],
      :evaluate_with        => ['bash', 'run-obj-c.sh'],
      :binaries_must_exist  => ['gcc', 'bash'],
      :version_against      => '/usr/bin/gcc',
      :extension            => 'm',
      :required_files       => {"#{@eval_path}/run-obj-c.sh" => 'run-obj-c.sh'},
      :before               => [
        '#import <Foundation/Foundation.h>',
      ].join("\n") + "\n",
    },
    'ocaml' => {
      :evaluate_with        => ['ocaml', '-noprompt'],
      :extension            => 'ml',
      :code_from_stdin      => true,
      :skip_preceding_lines => 2,
    },
    'ooc' => {
      :timeout              => 7,
      :evaluate_with        => ['rock', '-r'],
      :extension            => 'ooc',
    },
    'pascal' => {
      :evaluate_with        => ['bash', 'run-pascal.sh'],
      :binaries_must_exist  => ['fpc', 'bash'],
      :extension            => 'pas',
      :required_files       => {"#{@eval_path}/run-pascal.sh" => 'run-pascal.sh'},
      :before               => 'program RubletsEval(output);' + "\n",
    },
    'perl' => {
      :aliases              => ['perl5'],
      :evaluate_with        => ['perl'],
      :extension            => 'pl',
    },
    'perl6' => {
      :aliases              => ['nqp'],
      :evaluate_with        => ['nqp'],
      :extension            => 'pl',
    },
    'php' => {
      :evaluate_with        => ['php'],
      :extension            => 'php',
      :alter_code           => lambda { |code|
        code = "<?php #{code}" unless code.start_with?("<?")
        code.gsub!(/^<\? /, '<?php ') if code.start_with?("<? ")
        code
      },
    },
    'prolog' => {
      :aliases              => ['gprolog'],
      :evaluate_with        => ['gprolog'],
      :code_from_stdin      => true,
      :skip_preceding_lines => 3,
      :extension            => 'pro',
    },
    'python' => {
      :evaluate_with        => ['python'],
      :extension            => 'py',
      :before               => "import random\n",
    },
    'python3' => {
      :evaluate_with        => ['python3'],
      :extension            => 'py',
      :before               => "import random\n",
    },
    'racket' => {
      :aliases              => ['rkt'],
      :evaluate_with        => ['xargs', '-0', 'racket', '-e'],
      :binaries_must_exist  => ['racket', 'xargs'],
      :code_from_stdin      => true,
      :extension            => 'rkt',
    },
    'ruby' => {
      :aliases              => ['rb'],
      :evaluate_with        => 'ruby',
      :extension            => 'rb',
      :alter_code           => lambda { |code|
        eval_code = "begin\n"
        eval_code += "  result = ::Kernel.eval(#{code.inspect}, TOPLEVEL_BINDING)\n"
        if rubyversion == 'all'
          eval_code += '  puts RUBY_VERSION + " #{\'(\' + RUBY_ENGINE + \')\' if defined?(RUBY_ENGINE)} => " + result.inspect' + "\n"
        else
          eval_code += '  puts "=> " + result.inspect' + "\n"
        end
        eval_code += "rescue Exception => e\n"
        eval_code += '  puts "#{e.class}: #{e.message}"'
        eval_code += "\nend"
        eval_code
      },
    },
    'rust' => {
      :evaluate_with        => ['rusti'],
      :code_from_stdin      => true,
      :extension            => 'rs',
    },
    'sbcl' => {
      :aliases              => ['lisp'],
      :evaluate_with        => ['sbcl', '--noinform'],
      :extension            => 'lisp',
      :code_from_stdin      => true,
      :skip_preceding_lines => 1,
      :skip_ending_lines    => 1,
    },
    'scala' => {
      :evaluate_with        => [
        'scala',
        '-J-server', '-J-XX:+TieredCompilation', '-nocompdaemon', '-deprecation'
      ],
      :version_against      => '/opt/scala/bin/scala',
      :timeout              => 10,
      :extension            => 'scala',
      :code_from_stdin      => true,
      :skip_preceding_lines => 5,
      :skip_ending_lines    => 1,
    },
    'sh' => {
      :evaluate_with        => ['sh'],
      :extension            => 'sh',
    },
    'smalltalk' => {
      :evaluate_with        => ['gst'],
      :extension            => 'st',
    },
    'sml' => {
      :evaluate_with        => ['bash', 'run-smlnj.sh'],
      :extension            => 'sml',
      :binaries_must_exist  => ['sml', 'bash'],
      :skip_preceding_lines => 2,
      :skip_ending_lines    => 1,
      :required_files       => {
        "#{@eval_path}/run-smlnj.sh" => 'run-smlnj.sh',
      },
    },
    'sqlite' => {
      :evaluate_with        => ['sqlite3', Time.now.to_f.to_s],
      :aliases              => ['sqlite3'],
      :extension            => 'sqlite',
      :code_from_stdin      => true,
    },
    'tcl' => {
      :evaluate_with        => ['tclsh'],
      :extension            => 'tcl',
    },
    'zsh' => {
      :evaluate_with        => ['zsh'],
      :extension            => 'sh',
    },
  }

  # Be able to modify the map of languages dynamically.
  # This lets us add special cases to the map.
  class << self
    attr_accessor :languages
  end

  # Public: Finds a Hash for a given languages that we can evaluate.
  #
  # lang_name - A String containing a language name that a Hash should be
  #             returned for.
  #
  # Returns a Hash containing information about how we should execute a language
  #   or nil if the language is not supported.
  #
  def self.by_name(lang_name)
    return nil if lang_name == nil

    lang_name = lang_name.downcase

    language = nil
    language = languages[lang_name] if languages.has_key?(lang_name)

    if language
      language[:language_name] = lang_name.capitalize
      return language
    else
      languages.each do |lang, params|
        if !params[:aliases].nil? and params[:aliases].include?(lang_name)
          language = languages[lang]
          language[:language_name] = lang_name.capitalize
          return language
        end
      end
    end
    nil
  end

  # Public: A method to return, in human-readable form, a String that lists all
  #         the languages that we can evaluate.
  #
  # Returns a String containing all of the languages that we can evaluate.
  def self.list_all
    languages.keys.sort.join(', ')
  end

  # Public: Give the version of a supported language.
  #
  # language        - A Hash containing information about a language.
  # version_command - A String with the default way to get the version of the
  #                   language. A literal (sans quotes) "{}" will be replaced
  #                   with the FULL PATH to the binary. Otherwise the FULL
  #                   PATH will be appended to the end of the String.
  #
  # If the language has a defined :version_against, that path is used.
  # Otherwise, the first element of :evaluate_with is used.
  #
  # The binary to version against MUST be in $PATH or no version will return.
  #
  # The reason this uses package managers to do its work is because Rublets
  # supports (and likes supporting) newer, in-development languages, and
  # those often don't have stable releases, just git commits. Rather than
  # the maintainer of the language requiring a .git directory, and making
  # git a build requirement, so that the compiler compiles in the git hash
  # for `the_language --version`, we just assume that the *packager* of the
  # language will put the git commit (or at least the date that git was pulled
  # from) in the version of the package. This is required per e.g. Fedora
  # snapshot packages as seen here:
  # http://fedoraproject.org/wiki/Packaging:NamingGuidelines#Snapshot_packages
  #
  # This takes burden off of the developer, and still lets users be able to
  # quickly and easily find out how far out of date the version we're evaluating
  # against is. This is the reason that we rely on the package manager to show
  # what version we have.
  #
  # Examples
  #
  #   # Fedora, RHEL, CentOS, Scientific Linux, etc.
  #   Language.version(Language.by_name('php'), 'rpm -qf')
  #   # => php-cli-5.4.0-5.fc18.x86_64
  #
  #   # Debian, Ubuntu, etc.
  #   Language.version(Language.by_name('perl'),
  #     "dpkg-query -W -f '${Package}-${Version}\n' $(dpkg -S {} | awk -F: '{print $1}')"
  #
  # Returns the version of the language as a String, or nil if the language is
  #   not in $PATH.
  def self.version(language, version_command)
    if language[:version_lambda]
      return language[:version_lambda].call
    end

    # Use :version_against or :binaries_must_exist[0]
    binary = if language[:version_against]
               language[:version_against]
             elsif language[:binaries_must_exist]
               language[:binaries_must_exist][0]
             elsif language[:evaluate_with]
               language[:evaluate_with][0]
             end
    return nil unless binary

    # Get the absolute path of the interpreter/compiler.
    if language[:version_against]
      path_to_binary = language[:version_against]
    else
      path_to_binary = ''
      ENV['PATH'].split(':').each do |path|
        if File.exists? File.join(path, '/', binary)
          path_to_binary = File.join(path, '/', binary)
          break
        end
      end
      return nil if path_to_binary.empty?
    end

    # Swap out all '{}' with the actual path, if we need to.
    # If '{}' doesn't appear, just throw path_to_binary on the end.
    if version_command.include? '{}'
      version_command.gsub!('{}', path_to_binary)
    else
      version_command = "#{version_command} #{path_to_binary}"
    end

    return `#{version_command}`.strip
  end
end
