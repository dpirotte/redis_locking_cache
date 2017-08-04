require "forwardable"
require "redis"
require "securerandom"

class RedisLockingCache
  extend Forwardable

  LockSuffix = ":lock"
  ExpirySuffix = ":expiry"

  def initialize(redis)
    @redis = redis
  end

  def_delegators :@redis, :flushall

  def fetch(key, opts = {}, &block)
    expires_in = opts.fetch(:expires_in, 1)
    expires_in_ms = (expires_in * 1000).to_i
    lock_timeout = opts.fetch(:lock_timeout, 1)
    lock_timeout_ms = (lock_timeout * 1000).to_i
    lock_wait = opts.fetch(:lock_wait, 0.025)
    cache_wait = opts.fetch(:cache_wait, 1)

    lock_key = "#{key}#{LockSuffix}"

    cached, expiry = get_with_external_expiry(key)

    # If the key is nil, then we have no choice but to recompute
    # the value. To do so as politely as possible, only permit a single
    # concurrent caller to execute the block, and all other callers
    # must loop/sleep.
    if cached.nil?
      cache_wait_expiry = Time.now.to_f + cache_wait

      while cached.nil? && Time.now.to_f < cache_wait_expiry
        unless cached = get(key)
          attempt_lock_for(key, lock_timeout: lock_timeout_ms) do |locked|
            if locked
              cached = block.call
              set_with_external_expiry(key, cached, expires_in_ms)
            else
              sleep(lock_wait)
            end
          end
        end
      end

    # If the key is present, but the expiry key is not, then we have a
    # stale value to serve. In this case, assume that it is better to
    # serve the stale value as quickly as possible rather than wait for
    # a caller to update the value. The first caller to pass through
    # will acquire the lock and update the value, and future callers
    # will simply serve the stale value.
    # In this case, also, we do not want to return an error to the caller,
    # and instead we prefer to serve the stale value.

    elsif expiry.nil?
      attempt_lock_for(key, lock_timeout: lock_timeout_ms, raise: false) do |locked|
        if locked
          cached = block.call
          set_with_external_expiry(key, cached, expires_in_ms)
        end
      end
    end

    cached
  end

  def attempt_lock_for(key, opts = {})
    lock_id = SecureRandom.hex(16)
    lock_key = "#{key}#{LockSuffix}"
    should_raise = opts.fetch(:raise, true)

    if @redis.set(lock_key, lock_id, nx: true, px: opts.fetch(:lock_timeout,1000))
      begin
        yield true
      rescue => e
        if should_raise
          raise e
        end
      ensure
        compare_and_delete(lock_key, lock_id)
      end
    else
      yield false
    end
  end

  def expiry_key_for(key)
    "#{key}#{ExpirySuffix}"
  end

  def get(key)
    @redis.get(key)
  end

  def get_with_external_expiry(key)
    @redis.mget(key, expiry_key_for(key))
  end

  def set_with_external_expiry(key, value, expires_in_ms)
    @redis.set(key, value)
    @redis.set(expiry_key_for(key), 1, px: expires_in_ms)
  end

  def compare_and_delete(key, value)
    @redis.eval('if redis.call("get",KEYS[1]) == ARGV[1] then return redis.call("del",KEYS[1]) end', [key], [value])
  end
end
