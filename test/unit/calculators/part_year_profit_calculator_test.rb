require_relative "../../test_helper"

module SmartAnswer
  module Calculators
    class PartYearProfitCalculatorTest < ActiveSupport::TestCase
      setup do
        Timecop.freeze(Date.parse('2015-07-29'))
      end

      teardown do
        Timecop.return
      end

      context 'standard 12-month accounting period' do
        setup do
          @calculator = PartYearProfitCalculator.new(
            tax_credits_awarded_on: Date.parse('2016-02-20'),
            accounts_start_on: Date.parse('2015-04-06'),
            profit_for_current_period: Money.new(15000)
          )
        end

        should 'calculate basis period to begin on the accounts start date' do
          assert_equal Date.parse('2015-04-06'), @calculator.basis_period.begins_on
        end

        should 'calculate basis period to be one year long' do
          assert_equal Date.parse('2016-04-05'), @calculator.basis_period.ends_on
        end

        should 'calculate award period to begin at the beginning of the current tax year' do
          assert_equal Date.parse('2015-04-06'), @calculator.award_period.begins_on
        end

        should 'calculate award period to end on the award date' do
          assert_equal Date.parse('2016-02-20'), @calculator.award_period.ends_on
        end

        should 'calculate number of days in basis period (includes leap day)' do
          assert_equal 366, @calculator.basis_period.number_of_days
        end

        should 'calculate number of days in award period (does not include leap day)' do
          assert_equal 321, @calculator.award_period.number_of_days
        end

        should 'calculate profit per day (rounded down to nearest pence)' do
          assert_equal 40.98, @calculator.profit_per_day
        end

        should 'calculate part year profit (rounded down to nearest pound)' do
          assert_equal 13154, @calculator.part_year_profit
        end
      end
    end
  end
end
