require 'redis'
require 'securerandom'

class RedisLockingCache
  LockSuffix = ':lock'.freeze
  ExpirySuffix = ':expiry'.freeze

  def initialize(redis)
    @redis = redis
  end

  def fetch(key, expires_in: 1, lock_timeout: 1, lock_wait: 0.025, cache_wait: 1)
    expires_in_ms = (expires_in * 1000).to_i
    lock_timeout_ms = (lock_timeout * 1000).to_i

    cached, expiry = get_with_external_expiry(key)

    if cached.nil?
      # If the key is nil, then we have no choice but to recompute
      # the value. To do so as politely as possible, only permit a single
      # concurrent caller to execute the block, and all other callers
      # must loop/sleep.
      cache_wait_expiry = Time.now.to_f + cache_wait

      while cached.nil? && Time.now.to_f < cache_wait_expiry
        attempt_lock_for(key, lock_timeout: lock_timeout_ms) do |locked|
          if locked
            cached = yield
            set_with_external_expiry(key, cached, expires_in_ms)
          else
            sleep(lock_wait)
            cached = get(key)
          end
        end
      end

    elsif expiry.nil?
      # If the key is present, but the expiry key is not, then we have a
      # stale value to serve. In this case, assume that it is better to
      # serve the stale value as quickly as possible rather than wait for
      # a caller to update the value. The first caller to pass through
      # will acquire the lock and update the value, and future callers
      # will simply serve the stale value.
      # In this case, also, we do not want to return an error to the caller,
      # and instead we prefer to serve the stale value.

      attempt_lock_for(key, lock_timeout: lock_timeout_ms) do |locked|
        if locked
          begin
            cached = yield
            set_with_external_expiry(key, cached, expires_in_ms)
          rescue
          end
        end
      end
    end

    cached
  end

  def attempt_lock_for(key, lock_timeout: 1000, lock_id: SecureRandom.hex(16))
    if @redis.set(lock_key_for(key), lock_id, nx: true, px: lock_timeout)
      begin
        yield true
      ensure
        compare_and_delete(lock_key_for(key), lock_id)
      end
    else
      yield false
    end
  end

  def lock_key_for(key)
    "#{key}#{LockSuffix}"
  end

  def expiry_key_for(key)
    "#{key}#{ExpirySuffix}"
  end

  def get(key)
    @redis.get(key)
  end

  def get_with_external_expiry(key)
    [key, expiry_key_for(key)].map { |k| get(k) }
  end

  def set_with_external_expiry(key, value, expires_in_ms)
    @redis.set(key, value)
    @redis.set(expiry_key_for(key), 1, px: expires_in_ms)
  end

  LuaCompareAndDelete = <<-REDIS.gsub(/\s+/, ' ').freeze
    if redis.call("get", KEYS[1]) == ARGV[1] then
      return redis.call("del", KEYS[1])
    end
  REDIS

  def compare_and_delete(key, value)
    @redis.eval(LuaCompareAndDelete, [key], [value])
  end
end
