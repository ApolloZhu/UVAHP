//
//  Offenses.swift
//  UVAHP
//
//  Created by Apollo Zhu on 3/24/18.
//  Copyright © 2018 UVAHP. All rights reserved.
//

import Foundation
import CoreLocation

private let GOV = "iiHnOKfno2Mgkt5AynpvPpUQTEyxE77jo1RU8PIv"

extension CLLocation {
    func fetchStatistics(_ process: @escaping ([OffenseResponse.Results]?) -> Void) {
        fetchFIPS { (state, fips) in
            guard let state = state, let fips = fips else { return process(nil) }
            let url = URL(string: "https://api.usa.gov/crime/fbi/ucr/agencies/count/states/offenses/\(state)/counties/\(fips)?page=1&per_page=10&output=json&api_key=\(GOV)")!
            let task = URLSession.shared.dataTask(with: url) { (data, _, _) in
                guard let data = data
                    , let json = try? JSONDecoder().decode(OffenseResponse.self, from: data)
                    else { return process(nil) }
                process(json.results)
            }
            task.resume()
        }
    }
}

struct OffenseResponse: Decodable {
    struct Pagination: Decodable {
        let count, page, pages, per_page: Int
    }
    let pagination: Pagination
    struct Results: Decodable {
        let year, agency_id: Int
        let ori, state_postal_abbr, pub_agency_name, offense_code, offense_name, classification: String
    }
    let results: [Results]
}
