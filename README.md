# RedisLockingCache

[![Build Status](https://travis-ci.org/dpirotte/redis_locking_cache.svg?branch=master)](https://travis-ci.org/dpirotte/redis_locking_cache)
[![Coverage Status](https://coveralls.io/repos/github/dpirotte/redis_locking_cache/badge.svg?branch=master)](https://coveralls.io/github/dpirotte/redis_locking_cache?branch=master)

Warning: This gem is alpha quality and not intended for production use. Code of this nature is fraught with race conditions and edge cases, and this gem was quickly constructed as an example.

WIP Redis caching gem that attempts to mitigate [cache stampede](https://en.wikipedia.org/wiki/Cache_stampede) by only permitting a single concurrent cache request to refresh the cache at a time. While the cache is refreshing, the stale value will be served. If cache refresh raises an error, the stale value will be served.

This gem is inspired by some helpful behavior in Nginx's HTTP proxy module: [proxy_cache_lock](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_lock) and [proxy_cache_use_stale](https://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_use_stale).

## Installation

Coming soon...

## Usage

Coming soon...

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/redis_locking_cache. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the RedisLockingCache project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/redis_locking_cache/blob/master/CODE_OF_CONDUCT.md).
