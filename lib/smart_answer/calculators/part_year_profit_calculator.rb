module SmartAnswer
  module Calculators
    class PartYearProfitCalculator
      attr_accessor :tax_credits_awarded_on, :accounts_start_on, :profit_for_current_period

      def initialize(**args)
        @tax_credits_awarded_on = args[:tax_credits_awarded_on]
        @accounts_start_on = args[:accounts_start_on]
        @profit_for_current_period = args[:profit_for_current_period]
      end

      def basis_period
        DateRange.new(begins_on: accounts_start_on, duration: 1.year)
      end

      def award_period
        DateRange.new(begins_on: TaxYear.current.begins_on, ends_on: tax_credits_awarded_on)
      end

      def profit_per_day
        (profit_for_current_period / basis_period.number_of_days).floor(2)
      end

      def part_year_profit
        (profit_per_day * award_period.number_of_days).floor
      end
    end
  end
end
