# frozen_string_literal: true

module CensusClient
  class Response
    FORCE_SUCCESS_REGEX = /\+$/
    FORCE_FAILURE_REGEX = /!$/
    FORCE_SUCCESS_NO_BIRTHDATE_REGEX = /-$/

    attr_accessor(
      :barri,
      :date_of_birth,
      :document_number,
      :raw_response,
      :raw_response_body
    )

    def initialize(params = {})
      self.document_number = params[:document_number].upcase
      self.date_of_birth = params[:date_of_birth]
      self.raw_response = census_response
      self.raw_response_body = Nokogiri::XML(raw_response.body).remove_namespaces!

      first_barri_node = raw_response_body.xpath("//ssagavaVigents//ssagavaVigent//barri").first

      self.barri = first_barri_node.text if first_barri_node
    end

    def district_not_registered?
      barri.present? && barri == "-"
    end

    def self.registered_stubbed_body(birthdate)
      return unless birthdate

      xml_body = <<-TEXT
  <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <ssagavaVigents>
  <ssagavaVigent>
  <edat>#{Utils.age_from_birthdate(birthdate)}</edat>
  <habap1hab>SURNAME1</habap1hab>
  <habap2hab>SURNAME2</habap2hab>
  <habfecnac>#{birthdate}</habfecnac>
  <habnomcom>SURNAME1*SURNAME2,MARY</habnomcom>
  <habnomhab>NAME</habnomhab>
  <haborddir>STREETNAME (L')                         AV     40    0      0         3   4</haborddir>
  <habtoddir>AV STREETNAME (L'),   40 3 4</habtoddir>
  <sexe>D</sexe>
  </ssagavaVigent>
  </ssagavaVigents>
  TEXT
      xml_body
    end

    def self.registered_stubbed_body_no_birthdate
      xml_body = <<-TEXT
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ssagavaVigents>
<ssagavaVigent>
<barri>-</barri>
<edat>0</edat>
<habap1hab>SURNAME1</habap1hab>
<habap2hab>SURNAME2</habap2hab>
<habnomcom>SURNAME1*SURNAME2,NAME</habnomcom>
<habnomhab>NAME</habnomhab>
<sexe>-</sexe>
</ssagavaVigent>
</ssagavaVigents>
TEXT
      xml_body
    end

    def self.not_registered_stubbed_body
      xml_body = <<-TEXT
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<ssagavaVigents></ssagavaVigents>
TEXT
      xml_body
    end

    private

    def census_response
      if Rails.env.production?
        make_request
      elsif document_number.match?(FORCE_SUCCESS_REGEX)
        OpenStruct.new(body: self.class.registered_stubbed_body(date_of_birth))
      elsif document_number.match?(FORCE_SUCCESS_NO_BIRTHDATE_REGEX)
        OpenStruct.new(body: self.class.registered_stubbed_body_no_birthdate)
      elsif document_number.match?(FORCE_FAILURE_REGEX)
        OpenStruct.new(body: self.class.not_registered_stubbed_body)
      else
        make_request
      end
    end

    def make_request
      Faraday.new(url: Rails.application.secrets.census_url).get do |request|
        request.url("findEmpadronat", dni: document_number)
      end
    end
  end
end
