module SmartAnswer
  class AdditionalCommodityCodeFlow < Flow
    def define
      name 'additional-commodity-code'

      status :published
      satisfies_need "100233"

      # Q1
      multiple_choice :how_much_starch_glucose? do
        option 0  # 0 - 4.99
        option 5  # 5 - 24.99
        option 25 # 25 - 49.99
        option 50 # 50 - 74.99
        option 75 # 75 or more

        save_input_as :starch_glucose_weight

        next_node do |response|
          case response.to_i
          when 25
            :how_much_sucrose_up_to_50_percent_or_more?
          when 50
            :how_much_sucrose_up_to_30_percent_or_more?
          when 75
            :how_much_sucrose_up_to_5_percent_or_more?
          else
            :how_much_sucrose_up_to_70_percent_or_more?
          end
        end
      end

      # Q2ab
      multiple_choice :how_much_sucrose_up_to_70_percent_or_more? do
        option 0  # 0 - 4.99
        option 5  # 5 - 29.99
        option 30 # 30 - 49.99
        option 50 # 50 - 69.99
        option 70 # 70 or more

        save_input_as :sucrose_weight
        next_node :how_much_milk_fat?
      end

      # Q2c
      multiple_choice :how_much_sucrose_up_to_50_percent_or_more? do
        option 0  # 0 - 4.99
        option 5  # 5 - 29.99
        option 30 # 30 - 49.99
        option 50 # 50 or more

        save_input_as :sucrose_weight
        next_node :how_much_milk_fat?
      end

      # Q2d
      multiple_choice :how_much_sucrose_up_to_30_percent_or_more? do
        option 0  # 0 - 4.99
        option 5  # 5 - 29.99
        option 30 # 30 or more

        save_input_as :sucrose_weight
        next_node :how_much_milk_fat?
      end

      # Q2e
      multiple_choice :how_much_sucrose_up_to_5_percent_or_more? do
        option 0 # 0 - 4.99
        option 5 # 5 or more

        save_input_as :sucrose_weight
        next_node :how_much_milk_fat?
      end

      # Q3
      multiple_choice :how_much_milk_fat? do
        option 0  # 0 - 1.49
        option 1  # 1.5 - 2.99
        option 3  # 3 - 5.99
        option 6  # 6 - 8.99
        option 9  # 9 - 11.99
        option 12 # 12 - 17.99
        option 18 # 18 - 25.99
        option 26 # 26 - 39.99
        option 40 # 40 - 54.99
        option 55 # 55 - 69.99
        option 70 # 70 - 84.99
        option 85 # 85 or more

        save_input_as :milk_fat_weight

        next_node do |response|
          case response.to_i
          when 0, 1
            :how_much_milk_protein_up_to_60_percent_or_more?
          when 3
            :how_much_milk_protein_up_to_12_percent_or_more?
          when 6
            :how_much_milk_protein_d?
          when 9, 12
            :how_much_milk_protein_ef?
          when 18, 26
            :how_much_milk_protein_gh?
          else
            :commodity_code_result
          end
        end
      end

      # Q3ab
      multiple_choice :how_much_milk_protein_up_to_60_percent_or_more? do
        option 0  # 0 - 2.49
        option 2  # 2.5 - 5.99
        option 6  # 6 - 17.99
        option 18 # 18 - 29.99
        option 30 # 30 - 59.99
        option 60 # 60 or more

        save_input_as :milk_protein_weight

        next_node :commodity_code_result
      end

      # Q3c
      multiple_choice :how_much_milk_protein_up_to_12_percent_or_more? do
        option 0  # 0-2.49
        option 2  # 2.5-11.99
        option 12 # 12 or more

        save_input_as :milk_protein_weight

        next_node :commodity_code_result
      end

      # Q3d
      multiple_choice :how_much_milk_protein_d? do
        option 0  # 0-3.99
        option 4  # 4-14.99
        option 15 # 15 or more

        save_input_as :milk_protein_weight

        next_node :commodity_code_result
      end

      # Q3ef
      multiple_choice :how_much_milk_protein_ef? do
        option 0  # 0-5.99
        option 6  # 6-17.99
        option 18 # 18 or more

        save_input_as :milk_protein_weight

        next_node :commodity_code_result
      end

      # Q3gh
      multiple_choice :how_much_milk_protein_gh? do
        option 0 # 0-5.99
        option 6 # 6 or more

        save_input_as :milk_protein_weight

        next_node :commodity_code_result
      end

      outcome :commodity_code_result, use_outcome_templates: true do
        precalculate :calculator do
          Calculators::CommodityCodeCalculator.new(
            starch_glucose_weight: starch_glucose_weight,
            sucrose_weight: sucrose_weight,
            milk_fat_weight: milk_fat_weight,
            milk_protein_weight: milk_protein_weight || 0)
        end

        precalculate :commodity_code do
          calculator.commodity_code
        end

        precalculate :has_commodity_code do
          commodity_code != 'X'
        end
      end
    end
  end
end
