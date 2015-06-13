require 'sinatra'
require 'json'
require 'open-uri'
require 'twilio-ruby'

MY_NUMBER = ENV['MY_NUMBER']
SPREADSHEET_ID = ENV['SPREADSHEET_ID']

SONG_URL = "http://com.twilio.music.rock.s3.amazonaws.com/jlbrock44_-_Apologize_Guitar_DropC.mp3"

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
  media_url = params['MediaUrl0']

  if from == MY_NUMBER
    twiml = send_to_contacts(body, media_url)
  else
    twiml = send_to_me(from, body, media_url)
  end

  content_type 'text/xml'
  twiml
end

def send_to_contacts(body, media_url = nil)
  response = Twilio::TwiML::Response.new do |r|
    contacts_numbers.each do |num|
      r.Dial callerId: '+13122486038' do |d|
          d.Number num
          d.Say 'hello there', voice: 'alice'
        end
      r.Message to: num do |msg|
        msg.Body body
        msg.Media media_url unless media_url.nil?
      end
    end
  end
  response.text
end

def send_to_me(from, body, media_url = nil)
  name = contact_name(from)
  body = "#{name} (#{from}):\n#{body}"
  response = Twilio::TwiML::Response.new do |r|
    r.Message to: MY_NUMBER do |msg|
      msg.Body body
      msg.Media media_url unless media_url.nil?
    end
  end
  response.text
end