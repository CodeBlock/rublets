#!/usr/bin/env ruby
# encoding: utf-8
require 'fileutils'
require 'timeout'
require 'net/https'
require 'uri'

require 'rubygems'
require 'bundler/setup'
require 'json'
require 'future'
require 'nokogiri'
require 'pry'
require 'linguist/repository'
require 'evalso'
require 'httparty'
require 'eventmachine'

$LOAD_PATH.unshift File.dirname(__FILE__)
require 'eval/config'
require 'eval/eval'
require 'eval/languages'
require 'statistics-web/extra_languages'

Signal.trap("USR1") do
  begin
    # Allow for reloading, on-the-fly, some of our core files.
    load File.dirname(__FILE__) + "/eval/eval.rb"
    load File.dirname(__FILE__) + "/eval/languages.rb"
  rescue Exception => e
    puts "-" * 80
    puts "** Reload (USR1) Exception **"
    puts "#{e} (#{e.class})"
    puts e.backtrace
    puts "-" * 80
  end
end

class TenbitClient < EM::Connection
  def initialize network, config
    super()
    
    @network = network
    @config = config
    @buffer = ''
  end
  
  def connection_completed
    start_tls
  end

  def receive_data(data)
    @buffer += data
    while @buffer.include?("\n")
      line, @buffer = @buffer.split("\n", 2)
      pkt = JSON.parse(line, {:symbolize_names => true}) rescue nil
      receive_pkt(pkt) if pkt
    end
  end
  
  def send(pkt)
    send_data(pkt.to_json + "\n")
  end
  
  def msg(room, message, ex={})
    ex[:message] = message
    send({:op => 'act', :rm => room, :ex => ex})
  end
  
  def receive_pkt(pkt)
    puts "<<< #{pkt}"
    
    case pkt[:op]
    when 'welcome'
      send({:op => 'auth', :ex => { :method => 'password', :username => @config.username, :password => @config.password}})
    when 'error'
      STDERR.puts "10bit protocol error: #{pkt[:ex][:message] rescue 'no message'}"
      close_connection
    when 'act'
      return unless pkt[:ex][:message]
      on_msg(pkt[:rm], pkt[:sr], pkt[:ex][:message])
    else
      puts "Unknown opcode #{pkt[:op]}"
    end
  end
end

class RubletsBot < TenbitClient
  def on_msg(room, sender, message)
    puts "#{Time.now} #{room} <#{sender}> #{message}"
    
    matches = message.match(/^#{Configru.comchar}([\S]+)> ?(.*)/im)
    if matches.nil?
      matches = message.match(/\[\[([\S]+)(?::|) (.*)\]\]/im)
    end
    if matches && matches.size > 1
      the_lang = Language.by_name(matches[1])
      if the_lang
        future do
          sandbox = Sandbox.new(the_lang.merge({
                :owner                => sender,
                :code                 => matches[2],
                :pastebin_credentials => Configru.pastebin_credentials,
                :path                 => Configru.rublets_home,
              }))
          sandbox.initialize_directories
          chmod = the_lang[:required_files_perms] ? the_lang[:required_files_perms] : 0770
          the_lang[:required_files].each { |file,dest| sandbox.copy(file, dest, chmod) } unless the_lang[:required_files].nil?
          result = sandbox.evaluate
          msg(room, result.join("\n"))
          sandbox.rm_home!
        end
        return
      end
    end

    case message
    when /^#{Configru.comchar}#{Configru.comchar}([\S]+)> ?(.*)/im
      future do
        begin
          res = Evalso.run(:language => $1, :code => $2)
          stdout = if res.stdout != "" then "#{2.chr}stdout:#{2.chr} #{res.stdout} " else " " end
          stderr = if res.stderr != "" then "#{2.chr}stderr:#{2.chr} #{res.stderr}" else "" end
          msg(room, "[#{res.wall_time} ms] #{stdout}#{stderr}")
        rescue
          msg(room, "An error occurred while communicating with eval.so")
        end
      end
    when /^#{Configru.comchar}version (.+)/
      versions = []
      $1.gsub(' ', '').split(',').each do |given_language|
        language = Language.by_name(given_language)
        if language
          if version = Language.version(language, Configru.version_command)
            versions << version
          else
            versions << "[Unable to detect version for #{given_language}]"
          end
        else
          versions << "['#{given_language}' is not supported]"
        end
      end
      msg(room, versions.join(', '))
    when /^#{Configru.comchar}quickstats$/
      project = Linguist::Repository.from_directory("#{Configru.rublets_home}/evaluated/")
      languages = {}
      project.languages.each do |language, count|
        languages[language.name] = ((count.to_f/project.size)*100).round(2)
      end
      top_languages = Hash[*languages.sort_by { |k, v| v }.reverse[0...8].flatten]
      total_evals = Dir["#{Configru.rublets_home}/evaluated/*"].count
      msg(room, "#{sender}: #{total_evals} total evaluations. " + top_languages.map { |k,v| "#{k}: #{v}%"}.join(', ') + " ... ")
    when /^#{Configru.comchar}rubies$/
      # Lists all available rubies.
      rubies = Dir[File.join(Configru.rvm_path, 'rubies') + '/*'].map { |a| File.basename(a) }
      msg(room, "#{sender}: #{rubies.join(', ')} (You can specify 'all' to evaluate against all rubies, but this might be slowish.)")

    when /^#{Configru.comchar}lang(?:s|uages)$/
      msg(room, "supports: #{Language.list_all}", {:isaction => true})

    when /^#{Configru.comchar}#{Configru.comchar}lang(?:s|uages)$/
      msg(room, "Eval.so supports: #{Evalso.languages.values.map(&:name).sort.join(', ')}")

    # Ruby eval.
    when /^#{Configru.comchar}(([\w\.\-]+)?>?|>)> (.*)/m
      future do
        # Pull these out of the regex here, because the global captures get reset below.
        given_version = $2 # might be nil.
        code = $3

        rubyversion = Configru.default_ruby

        # If a version is given (so not default), scan ./rubies/* to see if it matches.
        # If there is one (and only one) match, move along and set rubyversion to that.
        # If there's more than one, or no match, warn the user and ignore the eval.
        unless given_version.nil?
          if given_version == 'all'
            rubyversion = 'all'
          else
            rubies = Dir[File.join(Configru.rvm_path, 'rubies') + '/*'].map { |a| File.basename(a) }
            rubies = rubies.delete_if { |ruby| ruby.scan(given_version).empty? }
            if rubies.count > 1
              if rubies.include? given_version
                rubyversion = given_version
              else
                msg(room, "#{sender}: You matched multiple rubies. Be more specific. See !rubies for the full list.") and next
              end
            elsif rubies.count == 0
              next
            end
            rubyversion = rubies[0]
          end
        end

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

        sandbox = Sandbox.new(
          :path                 => Configru.rublets_home,
          :evaluate_with        => ['bash', 'run-ruby.sh', Configru.rvm_path, rubyversion],
          :timeout              => 5,
          :extension            => 'rb',
          :language_name        => 'ruby',
          :owner                => sender,
          :code                 => eval_code,
          :binaries_must_exist  => ['ruby', 'bash'],
          :pastebin_credentials => Configru.pastebin_credentials
          )

        # This is a bit of a hack, but lets us set up the rvm environment and call the script.
        sandbox.initialize_directories
        sandbox.copy('eval/run-ruby.sh', 'run-ruby.sh', 0770)
        result = sandbox.evaluate
        msg(room, result.join("\n"))
        sandbox.rm_home!
      end
    end # end case
  rescue ThreadError
    msg(room, "Could not create thread.")
  end
end

EM.run do
  puts 'Connecting...'
  
  Configru.servers.each_pair do |name, server_cfg|
    EM.connect server_cfg.address, 10817, RubletsBot, name, server_cfg
  end
end 
