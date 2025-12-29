# Disable ActiveRecord middleware since we don't use a database
Rails.application.config.middleware.delete ActiveRecord::Migration::CheckPending
Rails.application.config.middleware.delete ActiveRecord::QueryCache
