# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "redis_locking_cache/version"

Gem::Specification.new do |spec|
  spec.name          = "redis_locking_cache"
  spec.version       = RedisLockingCache::VERSION
  spec.authors       = ["Dave Pirotte"]
  spec.email         = ["dpirotte@gmail.com"]

  spec.summary       = %q{Redis caching extension}
  spec.description   = %q{Redis caching extension}
  spec.homepage      = "https://github.com/dpirotte/redis_locking_cache"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "redis", "~> 3.3"

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "coveralls", "~> 0.8"
  spec.add_development_dependency "guard", "~> 2.14"
  spec.add_development_dependency "guard-minitest", "~> 2.4"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
