#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'logger'
require 'faraday'
require 'nokogiri'
require 'open-uri'
require 'yaml'

USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_0) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.854.0 Safari/535.2'

$LOG = Logger.new(STDOUT)
$LOG.level = Logger::INFO

def fetch_tweets(user)
  # TODO: Replace with Faraday.get
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
    text: text,
  }.to_json, 'Content-Type' => 'application/json')
  result = JSON.parse resp.body
  if result['ok']
    $LOG.info 'Success to post.'
  else
    $LOG.fatal "Failed to post. #{resp.body}"
    abort
  end
end

if __FILE__ == $PROGRAM_NAME
  config = YAML.safe_load File.open('config.yaml').read
  telegram_api_token = ENV['SAKE_TELEGRAM_API_TOKEN']
  telegram_channel = config['telegram_channel']
  ENV['SAKE_TELEGRAM_CHANNEL_JSON'].tap do |e|
    telegram_channel = JSON.parse(e) if e
  end
  unless telegram_api_token
    $LOG.fatal 'No `SAKE_TELEGRAM_API_TOKEN` found in ENV.'
    abort
  end
  healthchecks_url = ENV['SAKE_HEALTHCHECKS_URL']

  last_tweet = nil
  loop do
    tweets = fetch_tweets(config['twitter_user'])
    unless tweets
      $LOG.fatal 'Fetch error, no tweets'
      abort
    end
    filtered_tweets = filter_tweets(tweets, config['twitter_tags'])
    if filtered_tweets
      new_tweet = filtered_tweets[0]
      if last_tweet != new_tweet
        post_telegram(telegram_api_token, telegram_channel, new_tweet)
        last_tweet = new_tweet
      else
        $LOG.info "Already posted. #{new_tweet.split.join('')[..32]}..."
      end
    else
      $LOG.info 'No new tweets.'
    end
    Faraday.get healthchecks_url if healthchecks_url
    sleep 1800 # 0.5 hours
  end
end
