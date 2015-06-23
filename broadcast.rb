require 'sinatra'
require 'json'
require 'open-uri'
require 'twilio-ruby'

MY_NUMBER = ENV['MY_NUMBER']
SPREADSHEET_ID = ENV['SPREADSHEET_ID']

# your Twilio authentication credentials
ACCOUNT_SID = 'AC110468b70e790be35208e709669cf8c6'
ACCOUNT_TOKEN = '16a9be0421ed71770ba0dfcb16e4748e'

# base URL of this application
BASE_URL = "https://young-inlet-5522.herokuapp.com"

# Outgoing Caller ID you have previously validated with Twilio
CALLER_ID = '+13122486038'

SONG_ARRAY = [
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+Blank+Space.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+Shake+It+Off.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+Style.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+Bad+Blood.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+I+Knew+You+Were+Trouble.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+We+Are+Never+Ever+Getting+Back+Together.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+You+Belong+With+Me.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+Love+Story.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+Teardrops+On+My+Guitar.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+Fifteen.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+Back+To+December.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+22.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+Picture+To+Burn.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+Our+Song.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+Mine.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+White+Horse.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+Everything+Has+Changed.mp3",
  "http://taylor-swift-songs.s3.amazonaws.com/Taylor+Swift+-+Mean.mp3",
]

WELCOME_MESSAGE = "Welcome to TayCall. Enter a song number via your keypad to change the song at any time. Here's the full song list:"


def spreadsheet_url
  "https://spreadsheets.google.com/feeds/list/1GHln3W7Gm_0GZ_3xOoFz5HcEHLZXze9iYLnEojyuKr8/od6/public/values?alt=json"
end

def sanitize(number)
  "+1" + number.gsub(/$1|\+|\s|\(|\)|\-|\./, '')
end

def data_from_spreadsheet
  file = open(spreadsheet_url).read
  JSON.parse(file)
end

def contacts_from_spreadsheet
  contacts = {}
  data_from_spreadsheet['feed']['entry'].each do |entry|
    name = entry['gsx$name']['$t']
    number = entry['gsx$number']['$t']
    contacts[sanitize(number)] = name
  end
  contacts
end

def contacts_numbers
  contacts_from_spreadsheet.keys
end

def contact_name(number)
  contacts_from_spreadsheet[number]
end

post '/message' do
  if !params['From']
    content_type 'text/xml'
    ""
  else
    user_number = params['From']
    message_from_user = params['Body']
    makecall(user_number, message_from_user)  
    content_type 'text/xml'
    ""
  end
end

post '/initiatecall' do
  response = Twilio::TwiML::Response.new do |r|
    r.Pause
    r.Say "Welcome to TayCall.", :voice => 'alice'
    r.Say "Enter a song number via your keypad to change the song at any time. A full song list has been sent to you via SMS.", :voice => 'alice'
    r.Say "We will start by playing a random song.", :voice => 'alice'
    r.Redirect BASE_URL + "/playsong"
  end
  twiml = response.text
  
  content_type 'text/xml'
  twiml
end

post '/playsong' do
  response = Twilio::TwiML::Response.new do |r|
    
    r.Gather :numDigits => '2', :timeout => '1' do |g|
      if !params['Digits']
        song_number = rand(SONG_ARRAY.length)
      else
        if !/\A\d+\z/.match(params['Digits'])
          song_number = rand(SONG_ARRAY.length)
          g.Say "You have entered an invalid song number. Playing a random song.", :voice => 'alice'
        else
          song_number = params['Digits'].to_i
          if song_number >= SONG_ARRAY.length
            song_number = rand(SONG_ARRAY.length)
            g.Say "You have entered an invalid song number. Playing a random song.", :voice => 'alice'
          end          
        end
      end
      current_song = SONG_ARRAY[song_number]
  
      #Outputs array with Artist, Song e.g. [Taylor Swift , Blank Spaces]
      current_song_name = current_song.split('/')[-1].split('.')[-2].gsub(/[+]/, ' ').split('-')
      g.Say "This is #{current_song_name[1]}. By #{current_song_name[0]}.", :voice => 'alice'
    
      g.Play current_song
      g.Say "That was #{current_song_name[1]}. By #{current_song_name[0]}.", :voice => 'alice'
      g.Say "Playing another random song. Enter a song number via your keypad to change the song at any time.", :voice => 'alice'
    end
    r.Redirect BASE_URL + "/playsong"
  end
  twiml = response.text
  
  content_type 'text/xml'
  twiml
end

# Use the Twilio REST API to initiate an outgoing call
def makecall(user_number, message_from_user)
  @client = Twilio::REST::Client.new ACCOUNT_SID, ACCOUNT_TOKEN
    
  if message_from_user
    if /\A\d+\z/.match(message_from_user)
      song_number = message_from_user.to_i
      if song_number < SONG_ARRAY.length
        specified_song_number = song_number
      end          
    end
  end
    
  if !specified_song_number
    @call = @client.account.calls.create(
    :from => CALLER_ID,   # From your Twilio number
    :to => user_number,     # To any number
    # Fetch instructions from this URL when the call connects
    :url => BASE_URL + "/initiatecall"
    )
  
    @client.account.messages.create(:body => WELCOME_MESSAGE,
    :to => user_number,
    :from => CALLER_ID)
  
    song_list = ""
    SONG_ARRAY.each_with_index {|val, index| song_list +=  "#{index}: #{val.split('/')[-1].split('.')[-2].gsub(/[+]/, ' ')} \n" }
  
    @client.account.messages.create(:body => song_list,
    :to => user_number,
    :from => CALLER_ID)
  else
    @client.account.messages.create(:body => "Hello you've specified song #{specified_song_number}",
    :to => user_number,
    :from => CALLER_ID)
    
    @call = @client.account.calls.create(
    :from => CALLER_ID,   # From your Twilio number
    :to => user_number,     # To any number
    # Fetch instructions from this URL when the call connects
    :url => BASE_URL + "/playsong&Digits=#{specified_song_number}"
    )
  end
  
end
# @end snippet
