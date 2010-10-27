require 'savon'

class Prelink

  def initialize(wsdl_url,station_id,passcode)
    @client = Savon::Client.new(wsdl_url)

    @soap_header = "
    <preLinkHeader xmlns='http://www.prelink.co.za/'>
      <StationId>#{station_id}</StationId>
      <PassCode>#{passcode}</PassCode>
    </preLinkHeader>"
  end

  #@client = Savon::Client.new(GlobalProperty.find_by_property("prelink_wsdl_url").property_value)
  #station_id = GlobalProperty.find_by_property("prelink_station_id").property_value
  #passcode = GlobalProperty.find_by_property("prelink_passcode").property_value


  def soap_request(soap_body)
  end

  def order_request(encounter, options = {})
    patient = encounter.patient

    test_codes = options[:TestCodes] || encounter.observations.map{|observation|
      "<string>#{observation.answer_string}</string>"
    }

    soap_body = "
      <wsdl:dto>
        <wsdl:PriorityCode>#{options[:PriorityCode] || "R"}</wsdl:PriorityCode>
        <wsdl:DateCollected>#{options[:DateCollected] || DateTime.now}</wsdl:DateCollected>
        <wsdl:DateReceived>#{options[:DateReceived] || DateTime.now}</wsdl:DateReceived>
        <wsdl:FolioNumber>#{options[:FolioNumber] || encounter.encounter_id}</wsdl:FolioNumber>
        <wsdl:PatientFirstName>#{options[:PatientFirstName] || patient.first_name}</wsdl:PatientFirstName>
        <wsdl:PatientLastName>#{options[:PatientLastName] || patient.given_name}</wsdl:PatientLastName>
        <wsdl:PatientIdNumber>#{options[:PatientIdNumber] || patient.national_id}</wsdl:PatientIdNumber>
        <wsdl:PatientAge>#{options[:PatientAge] || patient.age}</wsdl:PatientAge>
        <wsdl:PatientDateOfBirth>#{options[:PatientDateOfBirth] || patient.birthdate}</wsdl:PatientDateOfBirth>
        <wsdl:GenderCode>#{options[:GenderCode] || patient.gender}</wsdl:GenderCode>
        <wsdl:DoctorLocationCode>#{options[:DoctorLocationCode] || encounter.location_id}</wsdl:DoctorLocationCode>
        <wsdl:TestCodes>#{test_codes}</wsdl:TestCodes>
      </wsdl:dto>
    "

    response = @client.order_request {|soap| 
      soap.header = @soap_header
      soap.body = soap_body
    }
    response.to_hash[:order_request_response][:order_request_result] unless response.soap_fault?
  end

  def test_codes
    response = @client.get_test_codes {|soap| 
      soap.header = @soap_header
    }
    return nil if response.soap_fault?
    # This looks nasty. That's soap for you
    # First we drill down through the xml response until we get to the elements we care about
    useful_elements = response.to_hash[:get_test_codes_response][:get_test_codes_result][:diffgram][:document_element][:dynamic_list]
    # Then we end up with an array of hashes with lots of extra stuff in them
    # So we call map on that array and then on each hash we reject the stuff we are not interested in
    # We get an array of hashes with test codes and names
    array_of_hashes = useful_elements.map{|test| test.reject{|key,value| (key != :test_code) and (key != :test_name) }}
    # We make this more useful by converting it to a single hash with the test_name as key and the test_code as value
    # Google for "create hash with inject" to understand how this works
    array_of_hashes.inject({}){ |new_hash, array_hash|
      new_hash[array_hash[:test_name]]=array_hash[:test_code]
      new_hash
    }
  end

  def request_result(request_number)
    self.request_results [request_number]
  end

  def request_results(request_numbers)
    soap_body = "
      <requestNumber>" + 
        request_numbers.map{|request_number| "<string>#{request_number}</string>"}.join + "
      </requestNumber>
    "
    response = @client.get_request_results {|soap| 
      soap.header = @soap_header
      soap.body = soap_body
    }
    response.to_hash unless response.soap_fault?
  end

end

