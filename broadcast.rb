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

MESSAGE = "Welcome to TayCall. Change the song at any time by entering a song number. Here's the full song list:"


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
    from = '+13126183612'
  else
    from = params['From']
  end
  
  makecall(from)
  
  twiml = send_ack_to_user(from)
  
  content_type 'text/xml'
  twiml
end

post '/initiatecall' do
  response = Twilio::TwiML::Response.new do |r|
    r.Pause
    r.Say "Welcome to TayCall.", :voice => 'alice'
    r.Say "Change the song at any time by entering a song number. A full song list has been sent to you via SMS.", :voice => 'alice'
    r.Say "We will start by playing a random song.", :voice => 'alice'
    r.Redirect BASE_URL + "/playsong"
  end
  twiml = response.text
  
  content_type 'text/xml'
  twiml
end

post '/playsong' do
  response = Twilio::TwiML::Response.new do |r|
    
    r.Gather :numDigits => '1', :timeout => '180' do |g|
      if !params['Digits']
        song_number = rand(SONG_ARRAY.length)
      else
        song_number = params['Digits'].to_i
      end
      current_song = SONG_ARRAY[song_number]
  
      #Outputs array with Artist, Song e.g. [Taylor Swift , Blank Spaces]
      current_song_name = current_song.split('/')[-1].split('.')[-2].gsub(/[+]/, ' ').split('-')
      g.Say "This is #{current_song_name[1]}. By #{current_song_name[0]}.", :voice => 'alice'
    
      g.Play current_song
      g.Say "That was #{current_song_name[1]}. By #{current_song_name[0]}.", :voice => 'alice'
      g.Say "Choose another song by entering a song number now.", :voice => 'alice'
    end
    r.Redirect BASE_URL + "/playsong"
  end
  twiml = response.text
  
  content_type 'text/xml'
  twiml
end


def send_ack_to_user(from)
  response = Twilio::TwiML::Response.new do |r|
    r.Message to: from do |msg|
      msg.Body MESSAGE
    end
  end
  response.text
end

# Use the Twilio REST API to initiate an outgoing call
def makecall(user_number)
  @client = Twilio::REST::Client.new ACCOUNT_SID, ACCOUNT_TOKEN
  
  @client.account.sms.messages.create(:body => MESSAGE,
  :to => user_number,
  :from => MY_NUMBER)
  
  song_list = ""
  SONG_ARRAY.each_with_index {|val, index| song_list +=  "#{index}: #{val.split('/')[-1].split('.')[-2].gsub(/[+]/, ' ')} \n" }
  
  @client.account.sms.messages.create(:body => song_list,
  :to => user_number,
  :from => MY_NUMBER)
  
  @call = @client.account.calls.create(
    :from => CALLER_ID,   # From your Twilio number
    :to => user_number,     # To any number
    # Fetch instructions from this URL when the call connects
    :url => BASE_URL + "/initiatecall"
  )
    
end
# @end snippet
