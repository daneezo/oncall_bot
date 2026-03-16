# app/models/api_key.rb

class ApiKey < ApplicationRecord

    validates :token, presence: true, uniqueness: true
    validates :name, presence: true
  
    # generate token automatically before validation on create
    before_validation :generate_token, on: :create
  
    # scope for finding only active keys
    scope :active, -> { where(active: true) }
  
    # finds an active key matching the token
    # returns nil if not found — treated as unauthorized
    def self.authenticate(token)
      active.find_by(token: token)
    end
  
    private
  
    def generate_token
      # SecureRandom.hex(32) generates a secure 64 character token
      self.token ||= SecureRandom.hex(32)
    end
  
  end