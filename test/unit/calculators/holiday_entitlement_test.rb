require_relative '../../test_helper'

module SmartAnswer::Calculators
  class HolidayEntitlementTest < ActiveSupport::TestCase

    def setup
      @calculator = HolidayEntitlement.new()
    end

    test "Hours in a time series" do
      assert_equal @calculator.hours_between_date(Date.today, Date.yesterday), 24
    end

    test "Make a hash into times" do
      seconds = @calculator.hours_as_seconds(@calculator.hours_between_date(Date.today, Date.yesterday))
      hash = @calculator.seconds_to_hash seconds
      assert_equal hash[:dd], 1
      assert_equal hash[:hh], 0
      assert_equal hash[:mm], 0
    end

    test "Fraction of a year" do
      start_of_year = Date.civil(Date.today.year, 1, 1)
      end_of_fraction = Date.civil(Date.today.year, 4, 1)
      fraction = sprintf "%.3f", @calculator.fraction_of_year(end_of_fraction, start_of_year)
      assert_equal fraction, "0.249"
    end

    context "rounding and formatting days" do
      should "round to 1 dp" do
        assert_equal '123.7', @calculator.format_days(123.6593)
      end

      should "strip .0" do
        assert_equal '23', @calculator.format_days(23.0450)
      end
    end

    context "calculating full-time or part-time holiday entitlement" do

      context "working for a full year" do

        should "calculate entitlement for 5 days a week" do
          calc = HolidayEntitlement.new(
            :days_per_week => 5
          )

          assert_equal 28, calc.holiday_entitlement_days
        end

        should "calculate entitlement for more than 5 days a week" do
          calc = HolidayEntitlement.new(
            :days_per_week => 6
          )

          # 28 is the max
          assert_equal 28, calc.holiday_entitlement_days
        end

        should "calculate entitlement for less than 5 days a week" do
          calc = HolidayEntitlement.new(
            :days_per_week => 3
          )

          assert_equal '16.80', sprintf('%.2f', calc.holiday_entitlement_days)
        end
      end # full year

      context "starting this year" do
        setup do
          @start_date = "2012-03-12"
        end

        should "calculate entitlement for 5 days a week" do
          calc = HolidayEntitlement.new(
            :start_date => @start_date,
            :days_per_week => 5
          )
          assert_equal '22.49', sprintf('%.2f', calc.holiday_entitlement_days)
        end

        should "calculate entitlement for more than 5 days a week" do
          calc = HolidayEntitlement.new(
            :start_date => @start_date,
            :days_per_week => 6
          )
          # TODO: is this correct, or should the 28 day cap be pro-rated
          assert_equal '26.99', sprintf('%.2f', calc.holiday_entitlement_days)
        end

        should "cap entitlement at 28 days" do
          calc = HolidayEntitlement.new(
            :start_date => "2012-01-10",
            :days_per_week => 7
          )
          assert_equal 28, calc.holiday_entitlement_days
        end

        should "calculate entitlement for less than 5 days per week" do
          calc = HolidayEntitlement.new(
            :start_date => @start_date,
            :days_per_week => 3
          )
          assert_equal '13.50', sprintf('%.2f', calc.holiday_entitlement_days)
        end
      end # starting this year

      context "leaving this year" do

        should "calculate entitlement for 5 days a week" do
          calc = HolidayEntitlement.new(
            :leaving_date => '2012-07-24',
            :days_per_week => 5
          )
          assert_equal '15.68', sprintf('%.2f', calc.holiday_entitlement_days)
        end

        should "calculate entitlement for more than 5 days a week" do
          calc = HolidayEntitlement.new(
            :leaving_date => '2012-07-24',
            :days_per_week => 6
          )
          assert_equal '18.82', sprintf('%.2f', calc.holiday_entitlement_days)
        end

        should "cap entitlement at 28 days" do
          calc = HolidayEntitlement.new(
            :leaving_date => "2012-12-10",
            :days_per_week => 7
          )
          assert_equal 28, calc.holiday_entitlement_days
        end

        should "calculate entitlement for less than 5 days a week" do
          calc = HolidayEntitlement.new(
            :leaving_date => '2012-07-24',
            :days_per_week => 3
          )
          assert_equal '9.41', sprintf('%.2f', calc.holiday_entitlement_days)
        end
      end # leaving this year
    end
  end
end
