# frozen_string_literal: true

require_relative 'lib'

require 'test/unit'

class TestTwitter < Test::Unit::TestCase
  def setup
    @twitter = Twitter.new 'Misa2_omoshiroi', ['#misa国日报',
                                               '#misa国午夜电台']
    @raw_tweets = ['叉叉是个痴情宝宝！',
                   "#misa国日报\n13 Oct 2020\n1.#misa国花边小报 暂试行，详情关注叉叉！\n2.misa国今日关注：要开发布会啦。\n3.misa状态：努力战胜自己hhh\n4.misa国今日建议：不要对自己深爱的人留下什么殉情的念想，拜托了。\n5.我很害怕，始终害怕连累你，初见就是如此，一直如此。但...此时我也变得不能接受变成回忆了。",
                   "Replying to\n          @Misa2_omoshiroi\n\n        \n        \n\n      \n\n    \n        #misa国午夜电台\n一帆风顺的我，没想到妈妈的反应会如此的夸张，夸张到她拿了一把刀好像真的要砍我一样。\n到底是不是真的？如果我不打飞那把刀，我会留下什么一生难忘的东西吗？\n那无所谓了。\n突然发现世界最亲的人失去了可以沟通的筹码，才是一切的开始。\n会发现自己越来越孤独。\n已经，十几年了呢。",
                   "#misa国午夜电台\n抑郁。\n我的一切精神问题，源自那个有些冷的冬夜。\n那时，我是被宠坏的孩子，无论是家庭还是天赋，都是随心所欲的样子。\n不断的凭着天赋在探索着与我年龄严重不符的世界。\n至于为什么是性不是学术，为什么非要喜欢女人还会记录在手机上。\n我觉得，这只是一种冥冥之中的自然选择罢了。"]
    @tweets = @raw_tweets.map { |t| @twitter.make_tweet t }
  end

  def test_tweet
    assert_equal @tweets, @raw_tweets
  end

  def test_reply
    assert_false @tweets[1].reply?
    assert_true @tweets[2].reply?
  end

  def test_tagged
    assert_false @tweets[0].tagged?
    assert_true @tweets[1].tagged?
  end

  def test_strip_reply
    tweet = @tweets[1].strip_reply
    assert_false tweet.reply?
    assert_false tweet.tagged?
  end

  def test_last_tweet
    assert_not_nil @twitter.last_tweet [@tweets[0], @tweets[2], @tweets[3], @tweets[1]]
    assert_nil @twitter.last_tweet [@tweets[0]]
  end
end

class TestTelegram < Test::Unit::TestCase
  class FakeTelegram < Telegram
    attr_reader :posted

    def initialize(post_first)
      super post_first, nil, nil
      @success = true
      @posted = 0
    end

    def perform_post(_msg)
      @posted += 1 if @success
    end

    def failure
      @success = false
      yield
      @success = true
    end
  end

  def test_post_first_true
    telegram = FakeTelegram.new true
    telegram.post 'A'
    assert_equal telegram.posted, 1
    telegram.post 'A'
    assert_equal telegram.posted, 1
    telegram.post 'B'
    assert_equal telegram.posted, 2
    telegram.post nil
    assert_equal telegram.posted, 2
  end

  def test_post_fail
    telegram = FakeTelegram.new true
    telegram.failure do
      telegram.post 'A'
    end
    assert_equal telegram.posted, 0
    telegram.post 'A'
    assert_equal telegram.posted, 1
  end

  def test_post_first_false
    telegram = FakeTelegram.new false
    telegram.post 'A'
    assert_equal telegram.posted, 0
    telegram.post 'A'
    assert_equal telegram.posted, 0
    telegram.post 'B'
    assert_equal telegram.posted, 1
  end

  # def test_post
  #   telegram = Telegram.new ENV['SAKE_TELEGRAM_API_TOKEN'], '@sake_test_channel'
  #   telegram.post 'test message'
  # end
end
