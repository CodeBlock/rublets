%w{commands handlers server user message connection manager}.each { |x| load File.join(File.dirname(__FILE__), "#{x}.rb") }

module Rubino
  class Bot
    def initialize(opts)
      @nick = opts['nicks'][0]
      @config = opts
      @last = nil
      @server = Server.new(opts['server'], opts['port'])
      @connected = false
    end

    def handle_command
      @commands ||= Commands.new
      words = @last.words

      return unless words[0] =~ /^#{@nick}.?$/

      i = words.length-1
      command = words[1..i].join('_').downcase
      until @commands.respond_to?(command) || i < 1
        i -= 1
        command = words[1..i].join('_').downcase
      end

      if @commands.respond_to?(command)
        rest = words[(i+1)..-1]
        @commands.message = @last
        response = @commands.__send__(command, *rest)
        if response.is_a?(Array) 
          if response[0] == :noprefix
              reply response[1..-1]
          else
              __send__(response[0], *response[1..-1])
          end
        else
          reply "#{@last.sender.nick}: #{response}"
        end # if response.is_a?(Array)
      end   # if @commands.respond_to?(command)
    end

    def raw(*args)
      args.each do |line|
        puts ">> #{line}\r\n"
        @connection.puts line
      end
    end

    def send(*args)
      raw "#{args[0].upcase} #{args[1]} :#{args[2..-1].join(' ')}"
    end

    def privmsg(recip, *args)
      send "PRIVMSG", recip, *args
    end

    def notice(recip, *args)
      send "NOTICE", recip, *args
    end

    def ctcp(recip, type, *args)
      privmsg recip, "\001#{type.to_s.upcase} #{args.join(' ')}\001"
    end

    def action(recip, *args)
      ctcp recip, :action, *args
    end

    def reply(*args)
      privmsg @last.recip, *args
    end

    def reaction(*args)
      action @last.recip, *args
    end

    def join(*args)
      send :join, args.join(',')
      @config['channels'] << args
    end

    def part(*args)
      send :part, args[0], args[1..-1].join(' ')
      @config['channels'].delete(args[0])
    end

    def quit(*args)
      send :quit, args.join(' ')
      @connected = false
    end

    alias :msg :privmsg
    alias :tell :privmsg
    alias :do :action
    alias :act :action
    alias :react :reaction

    def shutdown(*args)
      if args.length > 0
        quit(*args)
      else
        quit "I have been slain!"
      end
      @connection.close
    end

    def connect
      @connection = Connection.new(@server)
      @connected = true
      raw "USER #{@nick} * * :Rubino IRC bot", "NICK #{@nick}"
    end

    def handle(message)
      %w{commands handlers}.each do |x|
        filename = File.join(File.dirname(__FILE__), '..', 'custom', "#{x}.rb")
        load filename if File.exist?(filename)
      end
      @handler ||= Handlers.new(self, @config)
      @handler.handle(message)
    end

    def parse(line)
      %w{commands handlers}.each { |x| load File.join(File.dirname(__FILE__), "..", "custom", "#{x}.rb") }
      message = Message.new(line)
      @last = message
      if message.sender.nil?
        puts line
      else
        puts "[#{message.recip}/#{message.type}] <#{message.sender.nick}> #{message.text}"
      end
      handle(message)
    end

    def run
      i = 1
      while @connected
        loop do
          connect if @connection.eof?
          until @connection.eof?
            i = 1
            line = @connection.readline
            parse line
          end
          sleep i*5
          i += 1
        end
      end
      @connection.close
    end

  end # class Bot
end   # module Rubino
