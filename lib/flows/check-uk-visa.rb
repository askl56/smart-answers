status :published
satisfies_need "100982"

additional_countries = UkbaCountry.all

exclude_countries = %w(american-samoa british-antarctic-territory british-indian-ocean-territory french-guiana french-polynesia gibraltar guadeloupe holy-see martinique mayotte new-caledonia reunion st-pierre-and-miquelon wallis-and-futuna western-sahara)

country_group_ukot = %w(anguilla bermuda british-dependent-territories-citizen british-overseas-citizen british-protected-person british-virgin-islands cayman-islands falkland-islands montserrat st-helena-ascension-and-tristan-da-cunha south-georgia-and-south-sandwich-islands turks-and-caicos-islands)

country_group_non_visa_national = %w(andorra antigua-and-barbuda argentina aruba australia bahamas barbados belize bonaire-st-eustatius-saba botswana brazil british-national-overseas brunei canada chile costa-rica curacao dominica timor-leste el-salvador grenada guatemala honduras hong-kong hong-kong-(british-national-overseas) israel japan kiribati south-korea macao malaysia maldives marshall-islands mauritius mexico micronesia monaco namibia nauru new-zealand nicaragua palau panama papua-new-guinea paraguay pitcairn-island st-kitts-and-nevis st-lucia st-maarten st-vincent-and-the-grenadines samoa san-marino seychelles singapore solomon-islands tonga trinidad-and-tobago tuvalu usa uruguay vanuatu vatican-city)

country_group_visa_national = %w(armenia azerbaijan bahrain benin bhutan bosnia-and-herzegovina burkina-faso cambodia cape-verde central-african-republic chad comoros cuba djibouti dominican-republic equatorial-guinea fiji gabon georgia guyana haiti indonesia jordan kazakhstan north-korea kuwait kyrgyzstan laos madagascar mali mauritania morocco mozambique niger oman peru philippines qatar russia sao-tome-and-principe saudi-arabia suriname tajikistan taiwan thailand togo tunisia turkmenistan ukraine united-arab-emirates uzbekistan zambia)

country_group_datv = %w(afghanistan albania algeria angola bangladesh belarus bolivia burma burundi cameroon china colombia congo cyprus-north democratic-republic-of-congo ecuador egypt eritrea ethiopia gambia ghana guinea guinea-bissau india iran iraq cote-d-ivoire jamaica kenya kosovo lebanon lesotho liberia libya macedonia malawi moldova mongolia montenegro nepal nigeria the-occupied-palestinian-territories pakistan rwanda senegal serbia sierra-leone somalia south-africa south-sudan sri-lanka sudan swaziland syria tanzania turkey uganda venezuela vietnam yemen zimbabwe)

country_group_eea = %w(austria belgium bulgaria croatia cyprus czech-republic denmark estonia finland france germany greece hungary iceland ireland italy latvia liechtenstein lithuania luxembourg malta netherlands norway poland portugal romania slovakia slovenia spain sweden switzerland)

# Q1
country_select :what_passport_do_you_have?, :additional_countries => additional_countries, :exclude_countries => exclude_countries do
  save_input_as :passport_country

  next_node_if(:outcome_no_visa_needed, country_in(country_group_eea))
  next_node(:purpose_of_visit?)
end

# Q2
multiple_choice :purpose_of_visit? do
  option :tourism
  option :work => :staying_for_how_long?
  option :study => :staying_for_how_long?
  option :transit
  option :family
  option :marriage
  option :school
  option :medical
  save_input_as :purpose_of_visit_answer

  calculate :reason_of_staying do
    if responses.last == 'study'
      PhraseList.new(:study_reason)
    elsif responses.last == 'work'
      PhraseList.new(:work_reason)
    end
  end

  on_condition(responded_with(%w{tourism school medical})) do
    next_node_if(:outcome_visit_waiver) { %w(oman qatar united-arab-emirates).include?(passport_country) }
    next_node_if(:outcome_taiwan_exception) { passport_country == 'taiwan' }
  end

  on_condition(->(_) { country_group_non_visa_national.include?(passport_country) or country_group_ukot.include?(passport_country) }) do
    next_node_if(:outcome_school_n, responded_with(%w{tourism school}))
    next_node_if(:outcome_medical_n, responded_with('medical'))
  end
  next_node_if(:outcome_school_y, responded_with('school'))
  next_node_if(:outcome_general_y, responded_with('tourism'))
  next_node_if(:outcome_marriage, responded_with('marriage'))
  next_node_if(:outcome_medical_y, responded_with('medical'))

  on_condition(responded_with('transit')) do
    next_node_if(:planning_to_leave_airport?) do
      country_group_datv.include?(passport_country) or
         country_group_visa_national.include?(passport_country) or %w(taiwan venezuela).include?(passport_country)
    end
    next_node(:outcome_no_visa_needed)
  end

  on_condition(responded_with('family')) do
    next_node_if(:outcome_joining_family_m) { country_group_ukot.include?(passport_country) }
    next_node(:outcome_joining_family_y)
  end
end

#Q3
multiple_choice :planning_to_leave_airport? do
  option :yes
  option :no
  save_input_as :leaving_airport_answer

  next_node_if(:outcome_visit_waiver) { %w(venezuela taiwan).include?(passport_country) }
  on_condition(responded_with('yes')) do
    next_node_if(:outcome_transit_leaving_airport) { country_group_visa_national.include?(passport_country) }
    next_node_if(:outcome_transit_leaving_airport_datv) { country_group_datv.include?(passport_country) }
  end
  on_condition(responded_with('no')) do
    next_node_if(:outcome_transit_not_leaving_airport) { country_group_datv.include?(passport_country) }
    next_node_if(:outcome_no_visa_needed) { country_group_visa_national.include?(passport_country) }
  end
end

#Q4
multiple_choice :staying_for_how_long? do
  option :six_months_or_less
  option :longer_than_six_months
  save_input_as :period_of_staying

  on_condition(responded_with('longer_than_six_months')) do
    next_node_if(:outcome_study_y) { purpose_of_visit_answer == 'study' } #outcome 2 study y
    next_node_if(:outcome_work_y) { purpose_of_visit_answer == 'work' } #outcome 4 work y
  end
  on_condition(responded_with('six_months_or_less')) do
    on_condition(->(_) { purpose_of_visit_answer == 'study' }) do
      #outcome 12 visit outcome_visit_waiver
      next_node_if(:outcome_visit_waiver) { %w(oman qatar united-arab-emirates).include?(passport_country) }
      next_node_if(:outcome_taiwan_exception) { %w(taiwan).include?(passport_country) }
      #outcome 3 study m visa needed short courses
      next_node_if(:outcome_study_m) { (country_group_datv + country_group_visa_national).include?(passport_country) }
      #outcome 1 no visa needed
      next_node_if(:outcome_no_visa_needed) { (country_group_ukot + country_group_non_visa_national).include?(passport_country) }
    end
    on_condition(->(_) { purpose_of_visit_answer == 'work' }) do
      # outcome 5 work m visa needed short courses
      next_node_if(:outcome_work_m) { (country_group_datv + country_group_visa_national).include?(passport_country) }
      #outcome 5.5 work N no visa needed
      next_node_if(:outcome_work_n) { (country_group_ukot + country_group_non_visa_national).include?(passport_country) }
    end
  end
end


outcome :outcome_no_visa_needed do
  precalculate :no_visa_additional_sentence do
    if %w(croatia).include?(passport_country)
      PhraseList.new(:croatia_additional_sentence)
    elsif purpose_of_visit_answer == 'study'
      PhraseList.new(:study_additional_sentence)
    end
  end
end
outcome :outcome_study_y
outcome :outcome_study_m
outcome :outcome_work_y do
  precalculate :if_youth_mobility_scheme_country do
    if %w(australia canada japan monaco new-zealand hong-kong south-korea taiwan).include?(passport_country)
      PhraseList.new(:youth_mobility_scheme)
    end
  end
  precalculate :if_turkey do
    if %w(turkey).include?(passport_country)
      PhraseList.new(:turkey_business_person_visa)
    end
  end
end
outcome :outcome_work_m
outcome :outcome_work_n
outcome :outcome_transit_leaving_airport
outcome :outcome_transit_not_leaving_airport
outcome :outcome_joining_family_y
outcome :outcome_joining_family_m
outcome :outcome_visit_business_n
outcome :outcome_general_y do
  precalculate :if_china do
    if %w(china).include?(passport_country)
      PhraseList.new(:china_tour_group)
    end
  end
end
outcome :outcome_business_y
outcome :outcome_marriage
outcome :outcome_school_n
outcome :outcome_school_y
outcome :outcome_medical_y
outcome :outcome_medical_n
outcome :outcome_visit_waiver do
  precalculate :if_exception do
    if %w(venezuela).include?(passport_country)
      if leaving_airport_answer == "yes"
        PhraseList.new(:epassport_crossing_border)
      elsif leaving_airport_answer == "no"
        PhraseList.new(:epassport_not_crossing_border)
      end
    elsif %w(taiwan).include?(passport_country)
      if leaving_airport_answer == "yes"
        PhraseList.new(:passport_bio_crossing_border)
      else
        PhraseList.new(:passport_bio_not_crossing_border)
      end
    elsif %w(oman qatar united-arab-emirates).include?(passport_country)
      PhraseList.new(:electronic_visa_waiver)
    end
  end
  precalculate :outcome_title do
    if %w(venezuela).include?(passport_country)
      PhraseList.new(:epassport_visa_not_needed_title)
    elsif %w(taiwan).include?(passport_country)
      PhraseList.new(:passport_bio_visa_not_needed_title)
    elsif %w(oman qatar united-arab-emirates).include?(passport_country)
      PhraseList.new(:electronic_visa_waiver_needed_title)
    end
  end
end
outcome :outcome_transit_leaving_airport_datv
outcome :outcome_taiwan_exception
