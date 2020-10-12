#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'logger'
require 'http'
require 'nokogiri'
require 'yaml'

USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_0) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.854.0 Safari/535.2'

def json_parse(data)
  JSON.parse(data) if data
end

def fetch_tweets(user)
  html = HTTP[user_agent: USER_AGENT].follow.get("https://twitter.com/#{user}").to_s
  Nokogiri::HTML(html).css('.tweet-container').map(&:text).map(&:strip)
rescue StandardError
  []
end

def filter_tweets(tweets, tags)
  tweets.filter do |tweet|
    tags.map do |tag|
      tweet.include? tag
    end.any?
  end
end

def concat_tweets(tweets, user)
  index = tweets.index { |t| !reply?(t) }
  tweets[0..index].map { |t| strip_reply t, user }.reverse.join("\n")
end

def reply?(tweet)
  tweet.include? 'Replying to'
end

def strip_reply(dirty_tweet, user)
  clean_regex = Regexp.new "^Replying to[\\n\s]*@#{user}"
  dirty_tweet.gsub(clean_regex, '').strip
end

def post_telegram(api_token, chat_id, text)
  JSON.parse(HTTP.post("https://api.telegram.org/bot#{api_token}/sendMessage", json: {
                         chat_id: chat_id,
                         text: text
                       }).to_s)['ok']
rescue StandardError
  false
end

def healthcheck(url)
  return true unless url

  HTTP.get url
rescue StandardError
  false
end

if __FILE__ == $PROGRAM_NAME
  logger = if ENV['DOCKER_LOGS']
             Logger.new '/proc/1/fd/1'
           else
             Logger.new STDOUT
           end
  logger.level = Logger::INFO

  config = YAML.safe_load File.open('config.yaml').read
  twitter_user = config['twitter_user']
  telegram_api_token = ENV['SAKE_TELEGRAM_API_TOKEN']
  telegram_channel = json_parse(ENV['SAKE_TELEGRAM_CHANNEL_JSON']) || config['telegram_channel']
  unless telegram_api_token
    logger.fatal 'No `SAKE_TELEGRAM_API_TOKEN` found in ENV.'
    abort
  end
  healthchecks_url = ENV['SAKE_HEALTHCHECKS_URL']

  last_tweet = nil
  loop do
    tweets = fetch_tweets(twitter_user)
    filtered_tweets = filter_tweets(tweets, config['twitter_tags'])
    if filtered_tweets.empty?
      logger.info 'No tweets.'
    else
      new_tweet = concat_tweets(filtered_tweets, twitter_user)
      if last_tweet != new_tweet
        if post_telegram(telegram_api_token, telegram_channel, new_tweet)
          logger.info 'Success to post.'
          last_tweet = new_tweet
        else
          logger.error 'Failed to post. Try next time.'
        end
      else
        logger.info "Already posted. #{new_tweet.split.join('')}"
      end
    end
    sleep 60 until healthcheck(healthchecks_url)
    sleep 900 # 15 minutes
  end
end
