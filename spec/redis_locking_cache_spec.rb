require "spec_helper"

def parallel(n, &block)
  threads = []
  threads = n.times.map do
    Thread.new { block.call }
  end
  threads.each(&:join).map(&:value)
end

describe RedisLockingCache do
  it "has a version number" do
    ::RedisLockingCache::VERSION.wont_be_nil
  end

  describe "fetch" do
    let(:redis) { RedisLockingCache.new(Redis.new) }

    before(:each) do
      redis.flushall
    end

    describe "with missing cache key" do
      it "returns uncached values" do
        redis.fetch("cache key") { "cached" }.must_equal "cached"
      end

      it "only permits a single concurrent call to update the cache" do
        uncached_call_count = 0

        results = parallel(10) do
          redis.fetch("cache key") do
            sleep 0.1 # simulating an expensive call
            uncached_call_count += 1
            "cached"
          end
        end

        uncached_call_count.must_equal 1
        results.must_equal ["cached"] * 10
      end
    end

    describe "with expired cache key" do
      it "makes a single call to the origin" do
        redis.fetch("cache key", :expires_in => 0.1) { "cached" }
        sleep 0.2

        results = parallel(5) do
          redis.fetch("cache key") do
            sleep 0.1
            "new cached"
          end
        end

        results.sort.must_equal ["cached"] * 4 + ["new cached"]
      end

      it "serves the cached value on error" do
        redis.fetch("cache key", :expires_in => 0.1) { "cached" }
        sleep 0.2

        results = parallel(5) do
          redis.fetch("cache key") do
            sleep 0.1
            raise
          end
        end

        results.sort.must_equal ["cached"] * 5
      end
    end

    describe "with live cache key" do
      it "serves the cached value" do
        redis.fetch("cache key", :expires_in => 1) { "cached" }

        results = parallel(10) do
          redis.fetch("cache key") do
            "new cached"
          end
        end

        results.must_equal ["cached"] * 10
      end
    end
  end
end
