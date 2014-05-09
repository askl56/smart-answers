days_of_the_week = Calculators::MaternityPaternityCalculatorV2::DAYS_OF_THE_WEEK

## QM1
date_question :baby_due_date_maternity? do
  from { 1.year.ago(Date.today) }
  to { 2.years.since(Date.today) }

  calculate :calculator do
    Calculators::MaternityPaternityCalculatorV2.new(Date.parse(responses.last))
  end
  next_node :employment_contract?
end

## QM2
multiple_choice :employment_contract? do
  option :yes
  option :no
  calculate :maternity_leave_info do
    if responses.last == 'yes'
      PhraseList.new(:maternity_leave_table)
    else
      PhraseList.new(:not_entitled_to_statutory_maternity_leave)
    end
  end
  next_node :date_leave_starts?
end

## QM3
date_question :date_leave_starts? do
  from { 2.years.ago(Date.today) }
  to { 2.years.since(Date.today) }

  precalculate :leave_earliest_start_date do
    calculator.leave_earliest_start_date
  end

  calculate :leave_start_date do
    ls_date = Date.parse(responses.last)
    raise SmartAnswer::InvalidResponse if ls_date < leave_earliest_start_date
    calculator.leave_start_date = ls_date
    calculator.leave_start_date
  end

  calculate :leave_end_date do
    calculator.leave_end_date
  end
  calculate :leave_earliest_start_date do
    calculator.leave_earliest_start_date
  end
  calculate :notice_of_leave_deadline do
    calculator.notice_of_leave_deadline
  end

  calculate :pay_start_date do
    calculator.pay_start_date
  end
  calculate :pay_end_date do
    calculator.pay_end_date
  end
  calculate :employment_start do
    calculator.employment_start
  end
  calculate :ssp_stop do
    calculator.ssp_stop
  end
  next_node :did_the_employee_work_for_you?
end

## QM4
multiple_choice :did_the_employee_work_for_you? do
  option :yes => :is_the_employee_on_your_payroll?
  option :no => :maternity_leave_and_pay_result
  calculate :not_entitled_to_pay_reason do
    responses.last == 'no' ? :not_worked_long_enough : nil
  end
end

## QM5
multiple_choice :is_the_employee_on_your_payroll? do
  option :yes => :last_normal_payday? # NOTE: goes to shared questions
  option :no => :maternity_leave_and_pay_result

  calculate :not_entitled_to_pay_reason do
    responses.last == 'no' ? :must_be_on_payroll : nil
  end

  calculate :payday_exit do
    'maternity'
  end
  calculate :to_saturday do
    calculator.format_date_day calculator.qualifying_week.last
  end
end

## QM5.2 && QP6.2 && QA6.2
date_question :last_normal_payday? do
  from { 2.years.ago(Date.today) }
  to { 2.years.since(Date.today) }

  calculate :last_payday do
    calculator.last_payday = Date.parse(responses.last)
    raise SmartAnswer::InvalidResponse if calculator.last_payday > Date.parse(to_saturday)
    calculator.last_payday
  end
  next_node :payday_eight_weeks?
end

## QM5.3 && P6.3 && A6.3
date_question :payday_eight_weeks? do
  from { 2.year.ago(Date.today) }
  to { 2.years.since(Date.today) }

  precalculate :payday_offset do
    calculator.format_date_day calculator.payday_offset
  end

  calculate :last_payday_eight_weeks do
    payday = Date.parse(responses.last)
    payday += 1 if leave_type == 'maternity'
    raise SmartAnswer::InvalidResponse if payday > Date.parse(payday_offset)
    calculator.pre_offset_payday = payday
    payday
  end

  calculate :relevant_period do
    calculator.formatted_relevant_period
  end

  next_node_if(:pay_frequency?, ->{ %w{maternity paternity}.include?(payday_exit) })
  next_node_if(:padoption_employee_avg_weekly_earnings?, ->{ payday_exit == 'paternity_adoption' })
  next_node_if(:adoption_employees_average_weekly_earnings?, ->{ payday_exit == 'adoption' })
end

## QM5.4
multiple_choice :pay_frequency? do
  save_input_as :pay_pattern
  option :weekly => :earnings_for_pay_period? ## QM5.5
  option :every_2_weeks => :earnings_for_pay_period? ## QM5.5
  option :every_4_weeks => :earnings_for_pay_period? ## QM5.5
  option :monthly => :earnings_for_pay_period? ## QM5.5
end

## QM5.5
money_question :earnings_for_pay_period? do
  calculate :calculator do
    calculator.calculate_average_weekly_pay(pay_pattern, responses.last)
    calculator
  end
  calculate :average_weekly_earnings do
    calculator.average_weekly_earnings
  end
  next_node :how_do_you_want_the_smp_calculated?
end

## QM7
multiple_choice :how_do_you_want_the_smp_calculated? do
  option :weekly_starting
  option :usual_paydates

  save_input_as :smp_calculation_method

  next_node do |response|
    if response == "usual_paydates"
      if pay_pattern == "monthly"
        :when_in_the_month_is_the_employee_paid?
      else
        :when_is_your_employees_next_pay_day?
      end
    else
      :maternity_leave_and_pay_result
    end
  end
end

## QM8
date_question :when_is_your_employees_next_pay_day? do
  calculate :next_pay_day do
    calculator.pay_date = Date.parse(responses.last)
    calculator.pay_date
  end

  next_node :maternity_leave_and_pay_result
end

## QM9
multiple_choice :when_in_the_month_is_the_employee_paid? do
  option :first_day_of_the_month => :maternity_leave_and_pay_result
  option :last_day_of_the_month => :maternity_leave_and_pay_result
  option :specific_date_each_month => :what_specific_date_each_month_is_the_employee_paid?
  option :last_working_day_of_the_month => :what_days_does_the_employee_work?
  option :a_certain_week_day_each_month => :what_particular_day_of_the_month_is_the_employee_paid?

  save_input_as :monthly_pay_method
end

## QM10
value_question :what_specific_date_each_month_is_the_employee_paid? do
  calculate :pay_day_in_month do
    day = responses.last.to_i
    raise InvalidResponse unless day > 0 and day < 32
    calculator.pay_day_in_month = day
  end

  next_node :maternity_leave_and_pay_result
end

## QM11
checkbox_question :what_days_does_the_employee_work? do
  (0...days_of_the_week.size).each { |i| option i.to_s.to_sym }

  calculate :last_day_in_week_worked do
    calculator.work_days = responses.last.split(",").map(&:to_i)
    calculator.pay_day_in_week = responses.last.split(",").sort.last.to_i
  end
  next_node :maternity_leave_and_pay_result
end

## QM12
multiple_choice :what_particular_day_of_the_month_is_the_employee_paid? do
  days_of_the_week.each { |d| option d.to_sym }

  calculate :pay_day_in_week do
    calculator.pay_day_in_week = days_of_the_week.index(responses.last)
    responses.last
  end
  next_node :which_week_in_month_is_the_employee_paid?
end

## QM13
multiple_choice :which_week_in_month_is_the_employee_paid? do
  option :"first"
  option :"second"
  option :"third"
  option :"fourth"
  option :"last"

  calculate :pay_week_in_month do
    calculator.pay_week_in_month = responses.last
  end
  next_node :maternity_leave_and_pay_result
end

## Maternity outcomes
outcome :maternity_leave_and_pay_result do

  precalculate :pay_method do
    calculator.pay_method = (
      if monthly_pay_method
        if monthly_pay_method == 'specific_date_each_month' and pay_day_in_month > 28
          'last_day_of_the_month'
        else
          monthly_pay_method
        end
      elsif smp_calculation_method == 'weekly_starting'
        smp_calculation_method
      elsif pay_pattern
        pay_pattern
      end
    )
  end
  precalculate :smp_a do
    sprintf("%.2f", calculator.statutory_maternity_rate_a)
  end
  precalculate :smp_b do
    sprintf("%.2f", calculator.statutory_maternity_rate_b)
  end
  precalculate :lower_earning_limit do
    sprintf("%.2f", calculator.lower_earning_limit)
  end

  precalculate :notice_request_pay do
    calculator.notice_request_pay
  end

  precalculate :below_threshold do
    calculator.average_weekly_earnings and
      calculator.average_weekly_earnings < calculator.lower_earning_limit
  end

  precalculate :not_entitled_to_pay_reason do
    if below_threshold
      :must_earn_over_threshold
    else
      not_entitled_to_pay_reason
    end
  end

  precalculate :total_smp do
    unless not_entitled_to_pay_reason.present?
      sprintf("%.2f", calculator.total_statutory_pay)
    end
  end

  precalculate :maternity_pay_info do
    if not_entitled_to_pay_reason.present?
      pay_info = PhraseList.new(calculator.average_weekly_earnings ?
                                :not_entitled_to_smp_intro_with_awe : :not_entitled_to_smp_intro)
      pay_info << not_entitled_to_pay_reason
      pay_info << :not_entitled_to_smp_outro
    else
      pay_info = PhraseList.new(:maternity_pay_table, :paydates_table)
    end
    pay_info
  end

  precalculate :pay_dates_and_pay do
    rows = []
    unless not_entitled_to_pay_reason.present?
      calculator.paydates_and_pay.each do |date_and_pay|
        rows << %Q(#{date_and_pay[:date].strftime("%e %B %Y")}|£#{sprintf("%.2f", date_and_pay[:pay])})
      end
    end
    rows.join("\n")
  end
end
