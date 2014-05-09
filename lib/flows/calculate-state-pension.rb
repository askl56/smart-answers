# -*- coding: utf-8 -*-
status :published
satisfies_need "100245"

# Q1
multiple_choice :which_calculation? do
  save_input_as :calculate_age_or_amount

  option :age
  option :amount

  next_node :gender?
end

# Q2
multiple_choice :gender? do
  save_input_as :gender

  option :male
  option :female

  # optional text to include in a hint for a later question
  calculate :if_married_woman do
    if responses.last.eql? 'female'
      PhraseList.new(:married_woman_text)
    else
      ''
    end
  end

  next_node_if(:dob_age?) { calculate_age_or_amount == "age" }
  next_node(:dob_amount?)
end


# Q3:Age
date_question :dob_age? do
  from { 100.years.ago }
  to { Date.today }

  save_input_as :dob

  calculate :calculator do
    Calculators::StatePensionAmountCalculator.new(
      gender: gender, dob: dob, qualifying_years: nil)
  end

  calculate :state_pension_date do
    calculator.state_pension_date
  end

  calculate :pension_credit_date do
    calculator.state_pension_date(:female).strftime("%e %B %Y")
  end

  #TODO: refactor this so text lives in .yml file
  calculate :pension_credit_statement do
    if calculator.state_pension_date(:female) > Date.today
      "You may be entitled to receive Pension Credit from " + pension_credit_date + "."
    else
      ""
    end
  end

  calculate :formatted_state_pension_date do
    state_pension_date.strftime("%e %B %Y")
  end

  calculate :tense_specific_title do
    if state_pension_date > Date.today
      PhraseList.new(:will_reach_pension_age)
    else
      PhraseList.new(:have_reached_pension_age)
    end
  end

  calculate :formatted_pension_pack_date do
    4.months.ago(state_pension_date).strftime("%B %Y")
  end

  calculate :state_pension_age do
    calculator.state_pension_age
  end

  calculate :available_ni_years do
    calculator.ni_years_to_date
  end

  calculate :state_pension_age_statement do
    if state_pension_date > Date.today
      PhraseList.new(:state_pension_age_is)
    else
      PhraseList.new(:state_pension_age_was)
    end
  end

  validate { |dob| Date.parse(dob) <= Date.today }

  next_node_calculation(:calc) do |response|
    Calculators::StatePensionAmountCalculator.new(gender: gender, dob: response)
  end

  next_node_if(:too_young) { calc.under_20_years_old? }
  next_node_if(:near_state_pension_age) {
    calc.before_state_pension_date? and calc.within_four_months_one_day_from_state_pension?
  }
  next_node(:age_result)
end

# Q3:Amount
date_question :dob_amount? do
  from { 100.years.ago }
  to { Date.today }

  save_input_as :dob

  calculate :calculator do
    Calculators::StatePensionAmountCalculator.new(gender: gender, dob: dob)
  end

  calculate :state_pension_age do
    calculator.state_pension_age
  end

  calculate :state_pension_date do
    calculator.state_pension_date.to_date
  end

  calculate :formatted_state_pension_date do
    state_pension_date.strftime("%e %B %Y")
  end

  calculate :remaining_years do
    calculator.years_to_pension
  end

  calculate :available_ni_years do
    calculator.available_years
  end

  validate { |dob| Date.parse(dob) <= Date.today }
  next_node_calculation(:calculator) do |response|
    Calculators::StatePensionAmountCalculator.new(gender: gender, dob: response)
  end
  next_node_if(:too_young) { calculator.before_state_pension_date? && calculator.under_20_years_old? }
  next_node_if(:years_paid_ni?) { calculator.before_state_pension_date? }
  next_node(:reached_state_pension_age)
end

# Q4
value_question :years_paid_ni? do
  # part of a hint for questions 4, 7 and 9 that should only be displayed for women born before 1962
  precalculate :carer_hint_for_women do
    if gender == 'female' and (Date.parse(dob) < Date.parse('1962-01-01'))
      PhraseList.new(:carers_allowance_women_hint)
    else
      ''
    end
  end

  calculate :carer_hint_for_women_q9 do
    if gender == 'female' and (Date.parse(dob) < Date.parse('1962-01-01'))
      PhraseList.new(:carers_allowance_women_hint_q9)
    else
      ''
    end
  end


  calculate :qualifying_years do
    ni_years = Integer(responses.last)
    raise InvalidResponse if ni_years < 0 or ni_years > available_ni_years
    ni_years
  end


  calculate :available_ni_years do
    calculator.available_years_sum(Integer(responses.last))
  end

  next_node_if(:amount_result) { |ni| calculator.enough_qualifying_years_and_credits?(Integer(ni)) }
  next_node_if(:amount_result) { |ni| calculator.no_more_available_years?(Integer(ni)) && calculator.three_year_credit_age? }
  next_node_if(:years_of_work?) { |ni| calculator.no_more_available_years?(Integer(ni)) } # Q10
  next_node(:years_of_jsa?) # Q5
end

# Q5
value_question :years_of_jsa? do
  calculate :qualifying_years do
    jsa_years = Integer(responses.last)
    qy = (qualifying_years + jsa_years)
    raise InvalidResponse if jsa_years < 0 or !(calculator.has_available_years?(qy)) #jsa_years > available_ni_years #70
    qy
  end

  calculate :available_ni_years do
    calculator.available_years_sum(qualifying_years)
  end

  next_node_calculation(:ni) { |response| Integer(response) + qualifying_years }

  next_node_if(:amount_result) { calculator.enough_qualifying_years_and_credits?(ni) }
  next_node_if(:amount_result) { calculator.no_more_available_years?(ni) && calculator.three_year_credit_age? }
  next_node_if(:years_of_work?) { calculator.no_more_available_years?(ni) } # Q10
  next_node(:received_child_benefit?) # Q6
end


## Q6
multiple_choice :received_child_benefit? do
  option :yes
  option :no

  next_node_if(:years_of_benefit?) { |r| r == 'yes' }
  next_node_if(:amount_result) { |r| calculator.three_year_credit_age? }
  next_node(:years_of_work?)
end

## Q7
value_question :years_of_benefit? do

  precalculate :years_you_can_enter do
    calculator.years_can_be_entered(available_ni_years,22)
  end

  calculate :qualifying_years do
    benefit_years = Integer(responses.last)
    qy = (benefit_years + qualifying_years)
    if benefit_years > 22 and calculator.has_available_years?(qy)
      raise InvalidResponse, :error_maximum_hrp_years
    elsif benefit_years < 0 or !(calculator.has_available_years?(qy))
      raise InvalidResponse, :error_too_many_years
    end
    qy
  end

  calculate :available_ni_years do
    calculator.available_years_sum(qualifying_years)
  end

  next_node_calculation(:ni) { |benefit_years| qualifying_years + Integer(benefit_years) }
  next_node_if(:amount_result) {calculator.enough_qualifying_years_and_credits?(ni)}
  next_node_if(:amount_result) { calculator.no_more_available_years?(ni) && calculator.three_year_credit_age? }
  next_node_if(:years_of_work?) { calculator.no_more_available_years?(ni) } # Q10
  next_node(:years_of_caring?) # Q8
end

## Q8
value_question :years_of_caring? do
  save_input_as :caring_years

  precalculate :allowed_caring_years do
    today = Date.today
    #allow full years from 6 April each year
    (((today.month > 4 or (today.month == 4 and today.day > 5)) ? today.year : today.year - 1) - 2010)
  end

  precalculate :years_you_can_enter do
    calculator.years_can_be_entered(available_ni_years,allowed_caring_years)
  end

  calculate :qualifying_years do
    caring_years = Integer(responses.last)
    qy = (caring_years + qualifying_years)
    raise InvalidResponse if (caring_years < 0 or (caring_years > allowed_caring_years) or !(calculator.has_available_years?(qy)))
    qy
  end

  calculate :available_ni_years do
    calculator.available_years_sum(qualifying_years)
  end

  next_node_calculation(:ni) {|caring_years| qualifying_years + Integer(caring_years)}
  next_node_if(:amount_result) {calculator.enough_qualifying_years_and_credits?(ni)}
  next_node_if(:amount_result) { calculator.no_more_available_years?(ni) && calculator.three_year_credit_age? }
  next_node_if(:years_of_work?) { calculator.no_more_available_years?(ni) } # Q10
  next_node(:years_of_carers_allowance?) # Q9
end

## Q9
value_question :years_of_carers_allowance? do
  calculate :qualifying_years do
    caring_years = Integer(responses.last)
    qy = (caring_years + qualifying_years)
    raise InvalidResponse if caring_years < 0 or !(calculator.has_available_years?(qy))
    qy
  end

  next_node_calculation(:ni) { |caring_years| qualifying_years + Integer(caring_years) }
  next_node_if(:amount_result) { calculator.enough_qualifying_years_and_credits?(ni) or calculator.three_year_credit_age? }
  next_node(:years_of_work?)
end


## Q10
value_question :years_of_work? do
  precalculate :years_you_can_enter do
    calculator.years_can_be_entered(available_ni_years,3)
  end

  save_input_as :years_of_work_entered

  calculate :qualifying_years do
    work_years = responses.last.to_i
    qy = (work_years + qualifying_years)
    raise InvalidResponse if (work_years < 0 or work_years > 3)
    qy
  end

  next_node :amount_result

end

outcome :near_state_pension_age
outcome :reached_state_pension_age
outcome :too_young do
  precalculate :weekly_rate do
    sprintf("%.2f", calculator.current_weekly_rate)
  end
end
outcome :age_result

outcome :amount_result do
  precalculate :calc do
    Calculators::StatePensionAmountCalculator.new(
      gender: gender, dob: dob, qualifying_years: (qualifying_years)
    )
  end

  precalculate :qualifying_years_total do
    if calc.three_year_credit_age?
      qualifying_years + 3
    else
      if years_of_work_entered
        qualifying_years + calc.calc_qualifying_years_credit(years_of_work_entered.to_i)
      else
        ## Q10 was skipped because of flow optimisation
        qualifying_years + calc.calc_qualifying_years_credit(0)
      end
    end
  end

  precalculate :missing_years do
    (qualifying_years_total < 30 ? (30 - qualifying_years_total) : 0)
  end

  precalculate :calculator do
    Calculators::StatePensionAmountCalculator.new(
      gender: gender, dob: dob, qualifying_years: (qualifying_years_total)
    )
  end

  precalculate :formatted_state_pension_date do
    calculator.state_pension_date.strftime("%e %B %Y")
  end

  precalculate :state_pension_date do
    calculator.state_pension_date
  end

  precalculate :pension_amount do
    sprintf("%.2f", calculator.what_you_get)
  end

  precalculate :weekly_rate do
    sprintf("%.2f", calculator.current_weekly_rate)
  end

  precalculate :pension_loss do
    sprintf("%.2f", calculator.pension_loss)
  end

  precalculate :what_if_not_full do
    sprintf("%.2f", calculator.what_you_would_get_if_not_full)
  end

  precalculate :pension_summary do
    if calculator.pension_loss > 0
      PhraseList.new(:this_is_n_below_the_full_state_pension)
    else
      PhraseList.new(:this_is_the_full_state_pension)
    end
  end

  precalculate :result_text do
    phrases = PhraseList.new

    enough_qualifying_years = qualifying_years_total >= 30
    enough_remaining_years = remaining_years >= missing_years
    auto_years_entitlement = (Date.parse(dob) < Date.parse("6th October 1953") and (gender == "male"))

    if calc.within_four_months_one_day_from_state_pension?
      phrases << (enough_qualifying_years ? :within_4_months_enough_qy_years : :within_4_months_not_enough_qy_years)
      if Date.today < calc.state_pension_date - 35
        phrases << :pension_statement
      end
      phrases << (enough_qualifying_years ? :within_4_months_enough_qy_years_more : :within_4_months_not_enough_qy_years_more)
      phrases << :automatic_years_phrase if auto_years_entitlement and !enough_qualifying_years
    elsif !enough_qualifying_years
      phrases << (enough_remaining_years ? :too_few_qy_enough_remaining_years : :too_few_qy_not_enough_remaining_years)
      phrases << :automatic_years_phrase if auto_years_entitlement
    else
      phrases << :you_get_full_state_pension
    end

    phrases
  end

  precalculate :automatic_credits do
    date_of_birth = Date.parse(dob)
    if Date.civil(1957,4,5) < date_of_birth and date_of_birth < Date.civil(1994,4,6)
      PhraseList.new :automatic_credits
    else
      ''
    end
  end
end
