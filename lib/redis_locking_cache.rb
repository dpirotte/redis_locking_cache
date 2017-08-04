require "forwardable"
require "redis"
require "securerandom"

class RedisLockingCache
  extend Forwardable

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

    lock_key = "#{key}:lock"

    cached, expiry = get_with_external_expiry(key)

    if cached.nil?
      cache_wait_expiry = Time.now.to_f + cache_wait

      while cached.nil? && Time.now.to_f < cache_wait_expiry
        unless cached = @redis.get(key)
          lock_id = SecureRandom.hex(16)
          if @redis.set(lock_key, lock_id, nx: true, px: lock_timeout_ms)
            begin
              cached = block.call
              set_with_external_expiry(key, cached, expires_in_ms)
            ensure
              compare_and_delete(lock_key, lock_id)
            end
          else
            sleep(lock_wait)
          end
        end
      end
    elsif expiry.nil?
      lock_id = SecureRandom.hex(16)
      if @redis.set(lock_key, 1, nx: true, ex: lock_timeout)
        begin
          cached = block.call
          set_with_external_expiry(key, cached, expires_in_ms)
        rescue
          # TODO bubble up errors when appropriate
        ensure
          compare_and_delete(lock_key, lock_id)
        end
      end
    end

    cached
  end

  def expiry_key_for(key)
    "#{key}#{ExpirySuffix}"
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
