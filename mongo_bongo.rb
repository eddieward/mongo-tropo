require 'rubygems'

require 'tropo-webapi-ruby'
require 'sinatra'
require 'yaml'
require 'aws/s3'
require 'uri'
require 'open-uri'
require 'mongoid'

# MongoDB configuration
Mongoid.configure do |config|
  if ENV['MONGOHQ_URL']
    conn = Mongo::Connection.from_uri(ENV['MONGOHQ_URL'])
    uri = URI.parse(ENV['MONGOHQ_URL'])
    config.master = conn.db(uri.path.gsub(/^\//, ''))
  else
    config.master = Mongo::Connection.from_uri("mongodb://localhost:27017").db('test')
  end
end

# generate a random string for the file name
def secure_random_string(length = 8, non_ambiguous = false)
  characters = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a

  %w{I O l 0 1}.each { |ambiguous_character|
    characters.delete ambiguous_character
  } if non_ambiguous

  (0...length).map {
    characters[SecureRandom.random_number(characters.size)]
  }.join
end


# Open configuration file and connect to Amazon
AWS_CONFIG = YAML.load(File.open('config/amazon_s3.yml'))
AWS::S3::Base.establish_connection!(
    :access_key_id => AWS_CONFIG['access_key_id'],
    :secret_access_key => AWS_CONFIG['secret_access_key']
)

# Method that receives the file and sends to S3
post '/post_audio_to_s3' do
  begin
    AWS::S3::S3Object.store(params['file_name'],
                            File.open(params['filename'][:tempfile].path),
                            AWS_CONFIG['bucket_name'])
  end
end

post '/record.json' do

  t = Tropo::Generator.new
  v = Tropo::Generator.parse request.env["rack.input"].read

  callerID = v[:session][:from][:id]

  if callerID.nil?
    callerID = "an-unidentified-caller"
  end

  greeting = 'Hello.  Welcome to the Mongo Bongo. Please leave a message and we will listen to it.  Thank you for calling the Mongo Bongo.'

  filename = "message-" + secure_random_string

  filename = URI.escape(filename)

  t.on :event => 'hangup', :next => '/hangup.json?filename=' + filename + '&callerID=' + callerID

  t.record({:name => 'recording',
            :voice => "Veronica",
            :timeout => 60,
            :maxTime => 120,
            :format => "audio/mp3",
            :url => 'http://tropo-sphere.herokuapp.com/post_audio_to_s3?file_name=' + filename + ".mp3",
            :choices => {:terminator => "#"}
           }) do
    say :value => greeting
  end
  t.response
end

post '/hangup.json' do

  puts "You got a call from " + params[:callerID]

end


