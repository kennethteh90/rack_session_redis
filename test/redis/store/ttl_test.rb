require 'test_helper'

class MockRedis
  def initialize
    @sets = []
    @setexes = []
    @setnxes = []
  end

  def set(*a)
    @sets << a
  end

  def has_set?(*a)
    @sets.include?(a)
  end

  def setex(*a)
    @setexes << a
  end

  def has_setex?(*a)
    @setexes.include?(a)
  end

  def setnx(*a)
    @setnxes << a
  end

  def has_setnx?(*a)
    @setnxes.include?(a)
  end
end

class MockTtlStore < MockRedis
  include Redis::Store::Ttl
end

describe MockTtlStore do
  let(:key) { 'hello' }
  let(:mock_value) { 'value' }
  let(:options) { { expire_after: 3600 } }
  let(:redis) { MockTtlStore.new }

  describe '#set' do
    describe 'without options' do
      it 'must call super with key and value' do
        redis.set(key, mock_value)
        _(redis.has_set?(key, mock_value, nil)).must_equal true
      end
    end

    describe 'with options' do
      it 'must call setex with proper expiry and set raw to true' do
        redis.set(key, mock_value, options)
        _(redis.has_setex?(key, options[:expire_after], mock_value, raw: true)).must_equal true
      end
    end

    describe 'with nx and ex option' do
      it 'must call super with key and value and options' do
        set_options = { nx: true, ex: 3600 }
        redis.set(key, mock_value, set_options)
        _(redis.has_set?(key, mock_value, set_options)).must_equal true
      end
    end
  end

  describe '#setnx' do
    describe 'without expiry' do
      it 'must call super with key and value' do
        redis.setnx(key, mock_value)
        redis.has_setnx?(key, mock_value)
      end

      it 'must not call expire' do
        redis.expects(:expire).never
        redis.setnx(key, mock_value)
      end
    end

    describe 'with expiry' do
      it 'uses set under the hood to set expiry and nx' do
        redis.expects(:set).with(key, mock_value, ex: options[:expire_after], nx: true, raw: true)
        redis.setnx(key, mock_value, options)
      end
    end
  end
end
