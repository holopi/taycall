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

SONG_URL = "http://com.twilio.music.rock.s3.amazonaws.com/jlbrock44_-_Apologize_Guitar_DropC.mp3"

MESSAGE = "Thanks for your request. Taylor loves you!"

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
  from = params['From']
  body = params['Body']
  
  makecall (from)

  twiml = send_ack_to_user(from)
  
  content_type 'text/xml'
  twiml
end

get '/playsong' do
  response =   Twilio::TwiML::Response.new do |r|
    r.Say "Hello Stranger"
    r.Play SONG_URL
  end.text
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
def makecall(from)
  # parameters sent to Twilio REST API
  data = {
    :from => CALLER_ID,
    :to => from,
    :url => BASE_URL + '/playsong',
  }

  begin
    client = Twilio::REST::Client.new(ACCOUNT_SID, ACCOUNT_TOKEN)
    client.account.calls.create data
  rescue StandardError => bang
    redirect_to :action => '.', 'msg' => "Error #{bang}"
    return
  end

  redirect_to :action => '', 'msg' => "Calling #{from}..."
end
# @end snippet
