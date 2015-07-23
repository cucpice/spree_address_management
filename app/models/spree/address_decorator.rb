Spree::Address.class_eval do
  attr_accessor :address_type

  belongs_to :user, :class_name => Spree.user_class.to_s

  def self.required_fields
    Spree::Address.validators.map do |v|
      v.kind_of?(ActiveModel::Validations::PresenceValidator) ? v.attributes : []
    end.flatten
  end

  def same_as?(other)
    return false unless other.is_a?(Spree::Address)

    comparison_attributes == other.comparison_attributes
  end

  # Returns a subset of attributes for use by #same_as?
  def comparison_attributes
    a = attributes.except('id', 'updated_at', 'created_at', 'alternative_phone')
    a.each{|k, v|
      a[k] = v.downcase if v.is_a?(String)
    }
    a['state_name'] = nil if a['state_name'].blank?
    a
  end

  # can modify an address if it's not been used in an completed order
  def editable?
    new_record? || !Spree::Order.complete.where("bill_address_id = ? OR ship_address_id = ?", self.id, self.id).exists?
  end

  def can_be_deleted?
    shipments.empty? && Spree::Order.where("bill_address_id = ? OR ship_address_id = ?", self.id, self.id).count == 0
  end

  def to_s
    [
      "#{firstname} #{lastname}",
      "#{company}",
      "#{address1}",
      "#{address2}",
      "#{city} #{state_text} #{zipcode}",
      "#{country}"
    ].reject(&:empty?).join(" <br/>").html_safe
  end

  # UPGRADE_CHECK if future versions of spree have a custom destroy function, this will break
  def destroy
    if can_be_deleted?
      super
    else
      update_column :deleted_at, Time.now
    end
  end
end
