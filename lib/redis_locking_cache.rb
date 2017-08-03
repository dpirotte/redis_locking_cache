require "forwardable"
require "redis"

class RedisLockingCache
  extend Forwardable

  def initialize(redis)
    @redis = redis
  end

  def_delegators :@redis, :flushall

  def fetch(key, opts = {}, &block)
    new_expiry = opts.fetch(:expires_in, 1)
    lock_timeout = opts.fetch(:lock_timeout, 1)
    lock_wait = opts.fetch(:lock_wait, 0.025)
    cache_wait = opts.fetch(:cache_wait, 1)

    lock_key = "#{key}:lock"
    expiry_key = "#{key}:expiry"

    cached, expiry = @redis.mget(key, expiry_key)

    if cached.nil? || expiry.nil? # missing
      cache_wait_expiry = Time.now.to_f + cache_wait

      while cached.nil? && Time.now.to_f < cache_wait_expiry
        unless cached = @redis.get(key)
          if @redis.set(lock_key, 1, nx: true, ex: lock_timeout)
            begin
              cached = block.call
              @redis.mset(key, cached, expiry_key, Time.now.to_f + new_expiry)
            ensure
              @redis.del(lock_key) # Race condition here
            end
          end
          sleep lock_wait
        end
      end
    elsif expiry.to_f < Time.now.to_f
      # TODO remove lock key
      if @redis.set(lock_key, 1, nx: true, ex: lock_timeout)
        begin
          cached = block.call
          @redis.mset(key, cached, expiry_key, Time.now.to_f + new_expiry)
        rescue
          # TODO bubble up errors when appropriate
        ensure
          @redis.del(lock_key) # Race condition here
        end
      end
    end

    cached
  end
end
