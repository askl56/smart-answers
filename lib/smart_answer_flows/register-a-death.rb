module SmartAnswer
  class RegisterADeathFlow < Flow
    def define
      name 'register-a-death'
      status :published
      satisfies_need "101006"

      country_name_query = SmartAnswer::Calculators::CountryNameFormatter.new
      reg_data_query = SmartAnswer::Calculators::RegistrationsDataQuery.new
      translator_query = SmartAnswer::Calculators::TranslatorLinks.new
      country_has_no_embassy = SmartAnswer::Predicate::RespondedWith.new(%w(iran syria yemen))
      exclude_countries = %w(holy-see british-antarctic-territory)

      # Q1
      multiple_choice :where_did_the_death_happen? do
        save_input_as :where_death_happened
        option england_wales: :did_the_person_die_at_home_hospital?
        option scotland: :did_the_person_die_at_home_hospital?
        option northern_ireland: :did_the_person_die_at_home_hospital?
        option overseas: :which_country?
      end

      # Q2
      multiple_choice :did_the_person_die_at_home_hospital? do
        option :at_home_hospital
        option :elsewhere
        calculate :died_at_home_hospital do |response|
          response == 'at_home_hospital'
        end
        next_node :was_death_expected?
      end

      # Q3
      multiple_choice :was_death_expected? do
        option :yes
        option :no

        calculate :death_expected do |response|
          response == 'yes'
        end

        next_node :uk_result
      end

      # Q4
      country_select :which_country?, exclude_countries: exclude_countries do
        save_input_as :country_of_death

        calculate :current_location do |response|
          reg_data_query.registration_country_slug(response) || response
        end

        calculate :current_location_name_lowercase_prefix do
          country_name_query.definitive_article(country_of_death)
        end

        calculate :death_country_name_lowercase_prefix do
          current_location_name_lowercase_prefix
        end

        next_node_if(:commonwealth_result, reg_data_query.responded_with_commonwealth_country?)
        next_node_if(:no_embassy_result, country_has_no_embassy)
        next_node(:where_are_you_now?)
      end

      # Q5
      multiple_choice :where_are_you_now? do
        option :same_country
        option another_country: :which_country_are_you_in_now?
        option :in_the_uk

        calculate :another_country do |response|
          response == 'another_country'
        end

        calculate :in_the_uk do |response|
          response == 'in_the_uk'
        end

        define_predicate(:died_in_north_korea) do
          country_of_death == 'north-korea'
        end

        on_condition(responded_with('same_country')) do
          next_node_if(:north_korea_result, died_in_north_korea)
        end

        next_node_if(:which_country_are_you_in_now?, responded_with('another_country'))
        next_node(:oru_result)
      end

      # Q6
      country_select :which_country_are_you_in_now?, exclude_countries: exclude_countries do
        calculate :current_location do |response|
          reg_data_query.registration_country_slug(response) || response
        end

        calculate :current_location_name_lowercase_prefix do
          country_name_query.definitive_article(current_location)
        end

        define_predicate(:currently_in_north_korea) do
          response == 'north-korea'
        end

        next_node_if(:north_korea_result, currently_in_north_korea)
        next_node(:oru_result)
      end

      use_outcome_templates

      outcome :commonwealth_result
      outcome :no_embassy_result

      outcome :uk_result

      outcome :oru_result do
        precalculate :button_data do
          {text: "Pay now", url: "https://pay-register-death-abroad.service.gov.uk/start"}
        end

        precalculate :translator_link_url do
          translator_query.links[country_of_death]
        end

        precalculate :reg_data_query do
          SmartAnswer::Calculators::RegistrationsDataQuery.new
        end

        precalculate :document_return_fees do
          reg_data_query.document_return_fees
        end
      end

      outcome :north_korea_result do
        precalculate :reg_data_query do
          SmartAnswer::Calculators::RegistrationsDataQuery.new
        end

        precalculate :overseas_passports_embassies do
          location = WorldLocation.find(current_location)
          raise InvalidResponse unless location
          organisation = location.fco_organisation

          if organisation
            organisation.offices_with_service 'Births and Deaths registration service'
          else
            []
          end
        end
      end
    end
  end
end
