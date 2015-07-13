module SmartAnswer::Calculators
  class CountryNameFormatter

    COUNTRIES_WITH_DEFINITIVE_ARTICLES = %w(bahamas british-virgin-islands cayman-islands czech-republic democratic-republic-of-congo dominican-republic falkland-islands gambia maldives marshall-islands netherlands philippines seychelles solomon-islands south-georgia-and-south-sandwich-islands turks-and-caicos-islands united-arab-emirates)

    FRIENDLY_COUNTRY_NAME = {
      "democratic-republic-of-congo" => "Democratic Republic of Congo",
      "cote-d-ivoire" => "Cote d'Ivoire".html_safe,
      "pitcairn" => "Pitcairn Island",
      "south-korea" => "South Korea",
      "st-helena-ascension-and-tristan-da-cunha" => "St Helena, Ascension and Tristan da Cunha",
      "usa" => "the USA"
    }

    def definitive_article(country, capitalized=false)
      result = country_name(country)
      if COUNTRIES_WITH_DEFINITIVE_ARTICLES.include?(country)
        result = capitalized ? "The #{result}" : "the #{result}"
      end
      result
    end

    def country_name(country)
      WorldLocation.all.find { |c| c.slug == country }.name
    end

  end
end
