# config/initializers/sidekiq.rb

Sidekiq.configure_server do |config|
    # tell Sidekiq where Redis is running
    config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
  end
  
  Sidekiq.configure_client do |config|
    # client is what enqueues jobs
    config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
  end