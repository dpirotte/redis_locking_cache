require 'spec_helper'

def parallel(n)
  Array.new(n) { Thread.new { yield } }.each(&:join).map(&:value)
end

describe RedisLockingCache do
  let(:redis) { Redis.new }
  let(:redis_lock) { RedisLockingCache.new(redis) }

  before(:each) do
    redis.flushall
  end

  it 'has a version number' do
    ::RedisLockingCache::VERSION.wont_be_nil
  end

  describe 'expiry_key_for' do
    it 'formats an expiry key for the specified key' do
      redis_lock.expiry_key_for('foo').must_equal 'foo:expiry'
    end
  end

  describe 'lock_key_for' do
    it 'formats a lock key for the specified key' do
      redis_lock.lock_key_for('foo').must_equal 'foo:lock'
    end
  end

  describe 'compare_and_delete' do
    it 'deletes a key if its value matches' do
      redis.set('foo', 'bar')
      redis_lock.compare_and_delete('foo', 'bar').must_equal 1
    end

    it 'does not delete a key if its value does not match' do
      redis.set('foo', 'bar')
      redis_lock.compare_and_delete('foo', 'baz').must_be_nil
    end
  end

  describe 'get_with_external_expiry' do
    it 'returns a value and an expiry' do
      redis_lock.set_with_external_expiry('foo', 'bar', 1000)
      redis_lock.get_with_external_expiry('foo').must_equal %w[bar 1]
    end

    it 'returns a value and nil if the expiry has passed' do
      redis_lock.set_with_external_expiry('foo', 'bar', 10)
      sleep 0.05
      redis_lock.get_with_external_expiry('foo').must_equal ['bar', nil]
    end
  end

  describe 'attempt_lock_for' do
    it 'yields true to a block when lock is acquired' do
      redis_lock.attempt_lock_for('foo') do |locked|
        locked.must_equal true
      end
    end

    it 'yields false to a block when lock fails to acquire' do
      redis_lock.attempt_lock_for('foo') do
        redis_lock.attempt_lock_for('foo') do |locked|
          locked.must_equal false
        end
      end
    end

    it 'removes the lock key after the block is called' do
      redis_lock.attempt_lock_for('foo') do
        redis_lock.get(redis_lock.lock_key_for('foo')).wont_be_nil
      end
      redis_lock.get(redis_lock.lock_key_for('foo')).must_be_nil
    end

    it 'removes the lock key when an error is raised in the block' do
      proc do
        redis_lock.attempt_lock_for('foo') do
          redis_lock.get(redis_lock.lock_key_for('foo')).wont_be_nil
          raise
        end
      end.must_raise RuntimeError

      redis_lock.get(redis_lock.lock_key_for('foo')).must_be_nil
    end
  end

  describe 'fetch' do
    describe 'with missing cache key' do
      it 'returns uncached values' do
        redis_lock.fetch('cache key') { 'cached' }.must_equal 'cached'
      end

      it 'only permits a single concurrent call to update the cache' do
        uncached_call_count = 0

        results = parallel(10) do
          redis_lock.fetch('missing cache key') do
            sleep 0.1 # simulating an expensive call
            uncached_call_count += 1
            'cached'
          end
        end

        uncached_call_count.must_equal 1
        results.must_equal ['cached'] * 10
      end

      it 'does not swallow errors' do
        proc do
          redis_lock.fetch('cache key') { raise RuntimeError }
        end.must_raise RuntimeError
      end
    end

    describe 'with expired cache key' do
      it 'makes a single call to the origin' do
        redis_lock.fetch('cache key', expires_in: 0.1) { 'cached' }
        sleep 0.2

        results = parallel(5) do
          redis_lock.fetch('cache key') do
            sleep 0.1
            'new cached'
          end
        end

        results.sort.must_equal ['cached'] * 4 + ['new cached']
      end

      it 'swallows errors and serves the cached value' do
        redis_lock.fetch('cache key', expires_in: 0.1) { 'cached' }
        sleep 0.2

        results = parallel(5) do
          redis_lock.fetch('cache key') do
            sleep 0.1
            raise
          end
        end

        results.sort.must_equal ['cached'] * 5
      end
    end

    describe 'with live cache key' do
      it 'serves the cached value' do
        redis_lock.fetch('cache key', expires_in: 10) { 'cached' }

        results = parallel(10) do
          redis_lock.fetch('cache key') do
            'new cached'
          end
        end

        results.must_equal ['cached'] * 10
      end
    end
  end
end
