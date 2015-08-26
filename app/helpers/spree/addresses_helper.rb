module Spree::AddressesHelper
  def address_field(form, method, address_id = "b", &handler)
    content_tag :p, :id => [address_id, method].join, :class => "field" do
      if handler
        handler.call
      else
        is_required = Spree::Address.required_fields.include?(method)
        separator = is_required ? '<span class="required">*</span><br />' : '<br />'
        form.label(method) + separator.html_safe +
        form.text_field(method, :class => is_required ? 'required' : nil)
      end
    end
  end

  def address_state(form, country, address_id)
    country ||= Spree::Country.find(Spree::Config[:default_country_id])
    have_states = !country.states.empty?
    state_elements = [
      form.collection_select(:state_id, country.states.order(:name),
                            :id, :name,
                            {:include_blank => true},
                            {:class => have_states ? "required" : "hidden",
                            :disabled => !have_states}) +
      form.text_field(:state_name,
                      :class => !have_states ? "required" : "hidden",
                      :disabled => have_states)
      ].join.gsub('"', "'").gsub("\n", "")

    form.label(:state_id, Spree.t(:state)) +
      %Q(<span class="required" id="#{address_id}state-required">*</span><br />).html_safe +
      content_tag(:noscript, form.text_field(:state_name, :class => 'required')) +
      javascript_tag("document.write(\"#{state_elements.html_safe}\");")
  end

  # Returns a Spree::AddressBookList for the given order and user, both of
  # which may be nil.
  def get_address_list(order, user)
    if @order and @user
      # Non-guest order
      Spree::AddressBookList.new(@user, @order)
    elsif @order
      # Guest order
      Spree::AddressBookList.new(@order)
    elsif @user
      # User account
      Spree::AddressBookList.new(@user)
    else
      # Nothing; return a blank list
      Spree::AddressBookList.new(nil)
    end
  end
end


# XXX ---------------------------------------------------------------- XXX

# XXX
def uaddrcount(user, str=nil, options={})
  user = Spree::User.find(user.id) if user && user.id && !user.new_record? && !(user.ship_address_id_changed? || user.bill_address_id_changed?)
  order = Spree::Order.find_by_id(options[:order].id) || options[:order] if options[:order]
  ids = Spree::AddressBookList.new(user).addresses.map{|a| a.addresses.map(&:id)}
  puts "\e[1;30m-->U#{user.try(:id).inspect} has #{user.addresses.count rescue 0} addrs (#{ids}) [B: #{user.try(:bill_address_id).inspect} S: #{user.try(:ship_address_id).inspect}] at \e[0;1m#{str}\e[0;36m #{caller(1)[0][/dbook.*/]}\e[0m\n" rescue (puts $!, *caller; raise 'foo')

  if order
    puts "  \e[34mO: \e[1m#{order.id.inspect}(#{order.state})\e[0;34m B: \e[1m#{order.bill_address_id.inspect}\e[0;34m S: \e[1m#{order.ship_address_id.inspect}\e[0m"
  end
end

# XXX - Compares every address to every other address, showing which are the
# same.
def addrmatrix(*addresses)
  list = addresses.flatten.uniq

  list.each do |a|
    list.each do |b|
      mismatched_attrs = []
      b_attrs = b.comparison_attributes
      a.comparison_attributes.each do |k, v|
        if v != b_attrs[k]
          mismatched_attrs << "#{k.inspect}: #{a.id}:#{v.inspect} != #{b.id}:#{b[k].inspect}"
        end
      end

      puts "#{'%03d' % a.id} -> #{'%03d' % b.id} \e[1m#{a.same_as?(b) ? 'same' : 'diff'}\e[0m U#{a.user_id.inspect}\t#{mismatched_attrs.join(', ')}"
    end
  end
end

# Returns a String of the message and backtrace with ANSI highlighting and an
# outline in Unicode box drawing characters.  The +backtrace+ can also be an
# Exception.
# XXX
def hl_bt(backtrace, msg=nil)
  require 'io/console'

  if backtrace.is_a?(Exception)
    msg = [msg, backtrace.message].compact.join(': ')
    backtrace = backtrace.backtrace
    color = "\e[31m"
  else
    color = "\e[34m"
  end

  width = IO.console.winsize[1]
  divider = "#{"\u2500" * (width - 3)}\u257c\e[0m"
  leader = "#{color}\u2502\e[0m"

  str = "#{color}\u256d#{divider}\n"

  str << "#{leader}\e[1m#{msg}\e[0m\n" if msg

  str << backtrace.reject{|l|
    # Skip gems we don't care about
    l =~ %r{(gems/(act|factory|rack|rail|state|warden|capybara|rspec)|webrick)}
  }.map{|l|
    # Skip leading paths
    l = l[/(dbook|rubies|gems).*/] || l
    l = l[%r{/gems.*}] || l

    # Highlight the line
    "#{leader}  \e[36m" + l.sub(
      %r{/([^:/]+):(\d+):in `([^']*)'},
      "/\e[1;33m\\1\e[0m:\e[34m\\2\e[0m:in `\e[1;35m\\3\e[0m'\n"
    )
  }.join

  str << "#{color}\u2514#{divider}\n"

  str
end

# Prints a filtered backtrace with a Unicode box around it. XXX
def whereami(msg=nil)
  puts hl_bt(caller(1), msg)
end
