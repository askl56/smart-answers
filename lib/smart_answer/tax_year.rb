module SmartAnswer
  class TaxYear < DateRange
    class << self
      def current
        on(Date.today)
      end

      def on(date)
        tax_year = new(begins_in: date.year)
        tax_year.include?(date) ? tax_year : tax_year.previous
      end
    end

    def initialize(begins_in:)
      super(begins_on: Date.new(begins_in, 4, 6), duration: 1.year)
    end

    def previous
      self.class.new(begins_in: begins_on.year - 1)
    end
  end
end
