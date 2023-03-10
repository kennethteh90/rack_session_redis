require 'test_helper'

describe 'Redis::Store::Namespace' do
  def setup
    @namespace = 'theplaylist'
    @store  = Redis::Store.new namespace: @namespace, serializer: nil
    @client = @store.instance_variable_get(:@client)
    @rabbit = 'bunny'
    @default_store = Redis::Store.new
    @other_namespace = 'other'
    @other_store = Redis::Store.new namespace: @other_namespace
  end

  def teardown
    @store.flushdb
    @store.quit

    @default_store.flushdb
    @default_store.quit

    @other_store.flushdb
    @other_store.quit
  end

  it 'only decorates instances that need to be namespaced' do
    store  = Redis::Store.new
    client = store.instance_variable_get(:@client)
    client.expects(:call).with([:get, 'rabbit'])
    store.get('rabbit')
  end

  it "doesn't namespace a key which is already namespaced" do
    _(@store.send(:interpolate, "#{@namespace}:rabbit")).must_equal("#{@namespace}:rabbit")
  end

  it 'should only delete namespaced keys' do
    @default_store.set 'abc', 'cba'
    @store.set 'def', 'fed'

    @store.flushdb
    _(@store.get('def')).must_be_nil
    _(@default_store.get('abc')).must_equal('cba')
  end

  it 'should allow to change namespace on the fly' do
    @default_store.set 'abc', 'cba'
    @other_store.set 'foo', 'bar'

    _(@default_store.keys.sort).must_equal ['abc', 'other:foo']

    @default_store.with_namespace(@other_namespace) do
      _(@default_store.keys).must_equal ['foo']
      _(@default_store.get('foo')).must_equal('bar')
    end
  end

  it 'should not try to delete missing namespaced keys' do
    empty_store = Redis::Store.new namespace: 'empty'
    empty_store.flushdb
    _(empty_store.keys).must_be_empty
  end

  it 'should work with dynamic namespace' do
    $ns = 'ns1'
    dyn_store = Redis::Store.new namespace: -> { $ns }
    dyn_store.set 'key', 'x'
    $ns = 'ns2'
    dyn_store.set 'key', 'y'
    $ns = 'ns3'
    dyn_store.set 'key', 'z'
    dyn_store.flushdb
    r3 = dyn_store.get 'key'
    $ns = 'ns2'
    r2 = dyn_store.get 'key'
    $ns = 'ns1'
    r1 = dyn_store.get 'key'
    _(r1).must_equal('x') && _(r2).must_equal('y') && _(r3).must_be_nil
  end

  it 'namespaces setex and ttl' do
    @store.flushdb
    @other_store.flushdb

    @store.setex('foo', 30, 'bar')
    _(@store.ttl('foo')).must_be_close_to(30)
    _(@store.get('foo')).must_equal('bar')

    _(@other_store.ttl('foo')).must_equal(-2)
    _(@other_store.get('foo')).must_be_nil
  end

  describe 'method calls' do
    let(:store) { Redis::Store.new namespace: @namespace, serializer: nil }
    let(:client) { store.instance_variable_get(:@client) }

    it 'should namespace get' do
      client.expects(:call).with([:get, "#{@namespace}:rabbit"]).once
      store.get('rabbit')
    end

    it 'should namespace set' do
      client.expects(:call).with([:set, "#{@namespace}:rabbit", @rabbit])
      store.set 'rabbit', @rabbit
    end

    it 'should namespace setnx' do
      client.expects(:call).with([:setnx, "#{@namespace}:rabbit", @rabbit])
      store.setnx 'rabbit', @rabbit
    end

    it 'should namespace del with single key' do
      client.expects(:call).with([:del, "#{@namespace}:rabbit"])
      store.del 'rabbit'
    end

    it 'should namespace del with multiple keys' do
      client.expects(:call).with([:del, "#{@namespace}:rabbit", "#{@namespace}:white_rabbit"])
      store.del 'rabbit', 'white_rabbit'
    end

    it 'should namespace keys' do
      store.set 'rabbit', @rabbit
      _(store.keys('rabb*')).must_equal ['rabbit']
    end

    it 'should namespace ttl' do
      client.expects(:call).with([:ttl, "#{@namespace}:rabbit"]).once
      store.ttl('rabbit')
    end

    it 'wraps flushdb with appropriate KEYS * calls' do
      client.expects(:call).with([:flushdb]).never
      client.expects(:call).with([:keys, "#{@namespace}:*"]).once.returns(['rabbit'])
      client.expects(:call).with([:del, "#{@namespace}:rabbit"]).once
      store.flushdb
    end

    it 'skips flushdb wrapping if the namespace is nil' do
      client.expects(:call).with([:flushdb])
      client.expects(:call).with([:keys]).never
      store.with_namespace(nil) do
        store.flushdb
      end
    end
  end
end
