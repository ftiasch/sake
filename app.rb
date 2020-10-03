#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'logger'
require 'faraday'
require 'nokogiri'
require 'open-uri'
require 'yaml'

USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_0) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.854.0 Safari/535.2'

$LOG = if ENV['DOCKER_LOGS']
         Logger.new '/proc/1/fd/1'
       else
         Logger.new STDOUT
       end
$LOG.level = Logger::INFO

def fatal(msg)
  $LOG.fatal msg
  abort
end

def json_parse(data)
  JSON.parse(data) if data
end

def fetch_tweets(user)
  doc = Nokogiri::HTML(URI.open("http://twitter.com/#{user}", 'User-Agent' => USER_AGENT))
  doc.css('.tweet-container').map(&:text).map(&:strip)
end

def filter_tweets(tweets, tags)
  tweets.filter do |tweet|
    tags.map do |tag|
      tweet.include? tag
    end.any?
  end
end

def post_telegram(api_token, chat_id, text)
  resp = Faraday.post("https://api.telegram.org/bot#{api_token}/sendMessage", {
    chat_id: chat_id,
    text: text
  }.to_json, 'Content-Type' => 'application/json')
  JSON.parse resp.body
end

if __FILE__ == $PROGRAM_NAME
  config = YAML.safe_load File.open('config.yaml').read
  telegram_api_token = ENV['SAKE_TELEGRAM_API_TOKEN']
  telegram_channel = json_parse(ENV['SAKE_TELEGRAM_CHANNEL_JSON']) || config['telegram_channel']
  fatal 'No `SAKE_TELEGRAM_API_TOKEN` found in ENV.' unless telegram_api_token
  healthchecks_url = ENV['SAKE_HEALTHCHECKS_URL']

  last_tweet = nil
  loop do
    tweets = fetch_tweets(config['twitter_user'])
    filtered_tweets = filter_tweets(tweets, config['twitter_tags'])
    if filtered_tweets.empty?
      $LOG.info 'No tweets.'
    else
      new_tweet = filtered_tweets[0]
      if last_tweet != new_tweet
        result = post_telegram(telegram_api_token, telegram_channel, new_tweet)
        if result['ok']
          $LOG.info 'Success to post.'
          last_tweet = new_tweet
        else
          fatal "Failed to post. #{resp.body}"
        end
      else
        $LOG.info "Already posted. #{new_tweet.split.join('')}"
      end
    end
    Faraday.get healthchecks_url if healthchecks_url
    sleep 1800 # 0.5 hours
  end
end
