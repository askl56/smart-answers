require_relative '../../test_helper'

require 'smart_answer_flows/calculate-your-part-year-profit'

module SmartAnswer
  class CalculateYourPartYearProfitFlowTest < ActiveSupport::TestCase
    setup do
      @calculator = OpenStruct.new
      @flow = CalculateYourPartYearProfitFlow.build(@calculator)
    end

    should 'start when_did_your_tax_credits_award_end? question' do
      assert_equal :when_did_your_tax_credits_award_end?, @flow.start_state.current_node
    end

    context 'when answering when_did_your_tax_credits_award_end? question' do
      setup do
        setup_states_for_question(:when_did_your_tax_credits_award_end?, responding_with: '2016-02-20')
      end

      should 'store parsed response on calculator as tax_credits_awarded_on' do
        assert_equal Date.parse('2016-02-20'), @calculator.tax_credits_awarded_on
      end

      should 'go to when_do_your_business_accounts_start? question' do
        assert_equal :when_do_your_business_accounts_start?, @new_state.current_node
      end
    end

    context 'when answering when_do_your_business_accounts_start? question' do
      setup do
        setup_states_for_question(:when_do_your_business_accounts_start?, responding_with: '2015-04-06')
      end

      should 'store parsed response on calculator as accounts_start_on' do
        assert_equal Date.parse('2015-04-06'), @calculator.accounts_start_on
      end

      should 'go to what_is_your_taxable_profit? question' do
        assert_equal :what_is_your_taxable_profit?, @new_state.current_node
      end
    end

    context 'when answering what_is_your_taxable_profit? question' do
      setup do
        @calculator.basis_period = DateRange.new(begins_on: Date.parse('2015-04-06'), duration: 1.year)
        setup_states_for_question(:what_is_your_taxable_profit?, responding_with: '15000')
      end

      should 'make from_date available for interpolation in question title' do
        assert_equal Date.parse('2015-04-06'), @precalculated_state.from_date
      end

      should 'make to_date available for interpolation in question title' do
        assert_equal Date.parse('2016-04-05'), @precalculated_state.to_date
      end

      should 'store parsed response on calculator as profit_for_current_period' do
        assert_equal Money.new(15000), @calculator.profit_for_current_period
      end

      should 'go to outcome' do
        assert_equal :outcome, @new_state.current_node
      end
    end

    def setup_states_for_question(key, responding_with:)
      question = @flow.node(key)
      state = SmartAnswer::State.new(question)
      @precalculated_state = question.evaluate_precalculations(state)
      @new_state = question.transition(@precalculated_state, responding_with)
    end

    context 'when rendering the outcome' do
      setup do
        outcome = @flow.node(:outcome)
        state = SmartAnswer::State.new(outcome)
        state.calculator = stub('calculator',
          part_year_profit: 13154,
          basis_period: DateRange.new(begins_on: Date.parse('2015-04-06'), duration: 1.year),
          tax_credits_awarded_on: Date.parse('2016-02-20'),
          accounts_start_on: Date.parse('2015-04-06'),
          profit_for_current_period: 15000
        )
        presenter = OutcomePresenter.new('i18n-prefix', outcome, state)
        @body = presenter.body(html: false)
      end

      should 'display part_year_profit' do
        assert_match 'Your part-year taxable profit is £13,154.', @body
      end

      should 'display tax_credits_awarded_on' do
        assert_match 'Your tax credits award ended on: 20 February 2016', @body
      end

      should 'display accounts_start_on' do
        assert_match 'Your business accounts started on:  6 April 2015', @body
      end

      should 'display profit_for_current_period' do
        assert_match 'Your estimated taxable profit between  6 April 2015 and  5 April 2016 was: £15,000', @body
      end
    end
  end
end
