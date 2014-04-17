class Donation < ActiveRecord::Base
  FOR_CENTER = 1
  FOR_FOOD_FOR_HUNGRY = 2
  attr_accessible :center_id, :description, :donation_type, :received_by_user_id, :donor_name, :donor_email, :amount
  acts_as_sequenced scope: :receipt_number
  acts_as_sequenced start_at: 1

  validates_presence_of :donor_name, :amount, :center_id
  validates :donor_email, uniqueness: true, format: { with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i }
  validates :amount, :numericality => true

  belongs_to :user
  belongs_to :center

  after_create :add_unique_donation_receipt_number

  def send_donation_notification_to_donor(user)
    begin
      HealersConnectMailer.delay.send_donation_notification_to_donor(self, user.email, center.name)
    rescue Exception => e
      Rails.logger.error "Failed to send email, email address: #{donor_email}"
      Rails.logger.error "#{e.backtrace.first}: #{e.message} (#{e.class})"
    end
  end

  def add_unique_donation_receipt_number
    update_attribute(:receipt_number, generate_unique_receipt_number)
  end

  def generate_unique_receipt_number
    "#{Time.now.year}#{Time.now.strftime('%m')}/#{"%04d" % sequential_id.to_s}"
  end

  # Search donations with Multiselectbox
  def self.search(params)
      donation_type = params[:donation_type].present? ? params[:donation_type].reject { |c| c.empty? } : []
      user_id = params[:user_id].present? ? params[:user_id].reject { |c| c.empty? } : []
      if donation_type.present? || user_id.present?
        if donation_type.present? and donation_type.size < donation_type[0].split(' ').size
          donation_type = donation_type[0].split(' ')
        end
        if user_id.present? and user_id.size < user_id[0].split(' ').size
          user_id = user_id[0].split(' ')
        end
        with_donation_type_donations = Donation.where('donation_type in (?)', (donation_type.present? ? donation_type : []))
        with_user_donations = Donation.joins(:user).where(users: { id: (user_id.present? ? user_id : []) })
        donations = with_donation_type_donations + with_user_donations
      else
        donations = Donation.all
      end
      return donations
  end

  # Find donations by timline like weekly,monthly,yearly or by both for render chart
  def self.find_donation_by_timeline(timeline, donations)
    donations = donations.present? ? donations : Donation.all
    donations_by_timeline = case timeline
    when 'weekly'
    when 'monthly'
    when 'yearly'
      Hash[donations.group_by{ |u| u.created_at.beginning_of_month }.to_a.sort]
    end
  end

  # Find donations by "yearly" for chart
  def self.yearly_donations(donations)
    @array_for_yearly_chart = []
      donations.each do |month,donations|
        @array_for_yearly_chart << ["#{month.strftime('%B')}", donations.count.to_i]
    end
    @array_for_yearly_chart
  end

  # Render Chart
  def self.render_chart(options = {})
    data_table = GoogleVisualr::DataTable.new
    data_table.new_column('string', options[:col_x])
    data_table.new_column('number', options[:col_y])
    data_table.add_rows(options[:data_for_chart])

    if options[:required_formatter]
      formatter = GoogleVisualr::ArrowFormat.new
      formatter.columns(1)
      data_table.format(formatter)
    end
    opts = { :title => options[:chart_name], :legend => 'bottom' }
    options[:chart_type] == :bar
      if !options[:interactive].present?
        chart = GoogleVisualr::Interactive::ColumnChart.new(data_table, opts)
      else
        chart = GoogleVisualr::Image::BarChart.new(data_table, opts)
      end
    chart
  end
end
