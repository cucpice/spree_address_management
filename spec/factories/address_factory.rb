require 'spree/testing_support/factories'
require 'securerandom'

FactoryGirl.modify do
  # Modify the address factory to generate unique addresses.
  factory :address do
    address2 { SecureRandom.uuid }
  end
end
