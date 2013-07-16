require 'working_days'

module SmartAnswer::Calculators
  class VatPaymentDeadlines
    def initialize(period_end_date, payment_method)
      @period_end_date = period_end_date
      @payment_method = payment_method
    end

    def last_payment_date
      case @payment_method
      when 'direct-debit'
        5.working_days.after(@period_end_date + 1.month)
      when 'online-telephone-banking'
        @period_end_date + 1.month + 7.days
      when 'online-debit-credit-card', 'bacs-direct-credit', 'bank-giro'
        4.working_days.after(@period_end_date + 1.month)
      when 'chaps'
        7.working_days.after(@period_end_date + 1.month)
      when 'cheque'
        3.working_days.before(@period_end_date - 3.days)
      else
        raise ArgumentError.new("Invalid payment method")
      end
    end

    def funds_received_by
      case @payment_method
      when 'direct-debit'
        3.working_days.after(@period_end_date + 1.month + 7.days)
      when 'online-telephone-banking'
        # This doesn't really apply to online banking, but the flow expects this
        # to always return a date.
        self.last_payment_date
      when 'online-debit-credit-card', 'bacs-direct-credit', 'bank-giro'
        @period_end_date + 1.month + 7.days
      when 'chaps'
        7.working_days.after(@period_end_date + 1.month)
      when 'cheque'
        # Select previous working day if not a work_day
        0.working_days.before(@period_end_date)
      else
        raise ArgumentError.new("Invalid payment method")
      end
    end
  end
end