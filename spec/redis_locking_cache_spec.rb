require "spec_helper"

describe RedisLockingCache do
  it "has a version number" do
    ::RedisLockingCache::VERSION.wont_be_nil
  end
end
