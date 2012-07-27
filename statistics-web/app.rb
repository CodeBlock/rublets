require "rubygems"
require "bundler/setup"
require "sinatra"
require "language_sniffer"
require "backports"
require "time"

$: << File.dirname(__FILE__)
require "extra_languages"

$: << File.join(File.dirname(__FILE__), '..')
require "eval/config"

get '/' do
  evaluated_path = File.join(Configru.rublets_home, 'evaluated', '*')

  @languages   = Hash.new { |h,k| h[k] = 0 }
  @users       = Hash.new { |h,k| h[k] = 0 }
  @evaluations = Hash.new { |h,k| h[k] = 0 }

  Dir[evaluated_path].each do |file|
    language = LanguageSniffer.detect("#{file}").language
    puts file if language.nil?
    language.nil? ? @languages['unknown'] += 1 : @languages[language.name] += 1

    user = file.split('-')[5]
    @users[user] += 1

    time = Time.parse(file.rpartition('-').first.rpartition('-').first)
    @evaluations[time] += 1
  end

  erb :index
end


Dir.chdir('/opt/rublets')

[
  'programble-apricot',
].each do |name|
  if File.exists?(name)
    Dir.chdir(name)
    `git pull origin master`
  else
    owner, repo = name.split('-')
    `git clone git://github.com/#{owner}/#{repo}.git #{name}`
  end
end

post '/rublets/pull' do
  push = JSON.parse(params[:payload])
  directory = "/opt/rublets/#{push['repository']['owner']['name']}-#{push['repository']['name']}"
  if File.exists?(directory)
    Dir.chdir(directory)
    `git pull origin master`
  else
    puts 'Whoopsie! An error occurred: The directory #{directory} was not found.'
  end
end
