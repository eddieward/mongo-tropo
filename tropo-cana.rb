require 'tropo-webapi-ruby'
require 'sinatra'
require 'rest-client'
require 'yaml'
require 'aws/s3'


filename = ""
callerID = ""


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

  filename = v[:session][:headers]['x-filename']

  if filename == nil
    # generate a random string for the file name
    def secure_random_string(length = 32, non_ambiguous = false)
      characters = ('a'..'z').to_a + ('A'..'Z').to_a + ('0'..'9').to_a

      %w{I O l 0 1}.each { |ambiguous_character|
        characters.delete ambiguous_character
      } if non_ambiguous

      (0...length).map {
        characters[SecureRandom.random_number(characters.size)]
      }.join
    end

    filename = "m-" + secure_random_string
  else
    filename = "m-" + filename
  end

  t.on :event => 'hangup', :next => '/hangup.json'

  t.record({:name => 'recording',
            :voice => "kate",
            :timeout => 10,
            :maxTime => 30,
            :format => "audio/mp3",
            :url => 'http://tropo-cana.herokuapp.com/post_audio_to_s3?file_name=' + filename + ".mp3",
            :choices => { :terminator => "#"}
           }) do
    say :value => 'Hello. Welcome to yak rabbit. Please leave a message after the tone and I will text you in a moment. yak rabbit.  Hop to it!'
  end
  t.response
end

post '/hangup.json' do

  blurb = "Hello Eddie.  You got a call from: " + callerID

  RestClient.get 'http://yakrabbit.herokuapp.com/new-message', {:params => {:uuid => filename, :caller_id => callerID}}
  RestClient.get 'http://digitiz-ed.com/message-notification', {:params => {:blurb => blurb}}
end

post '/text.json' do

  t = Tropo::Generator.new
  v = Tropo::Generator.parse request.env["rack.input"].read


  number = v[:session][:parameters][:numbertotext]
  blurb = v[:session][:parameters][:blurb]

  t.call(:to => "+1" + number, :network => "SMS")
  t.say(:value => blurb)

  puts number # ----------------------------------------
  puts blurb # -----------------------------------------


  t.response

end


post '/agent.json' do

  t = Tropo::Generator.new
  v = Tropo::Generator.parse request.env["rack.input"].read


  number = v[:session][:parameters][:numbertotext]
  blurb = v[:session][:parameters][:blurb]

  t.call(:to => "+1" + number, :network => "SMS")
  t.say(:value => blurb)

  puts number # ----------------------------------------
  puts blurb # -----------------------------------------


  t.response

end

