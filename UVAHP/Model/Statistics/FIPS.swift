//
//  FIPS.swift
//  UVAHP
//
//  Created by Apollo Zhu on 3/24/18.
//  Copyright © 2018 UVAHP. All rights reserved.
//

import Foundation
import CoreLocation

fileprivate let fipsURL = ""

struct FIPSWrapper: Decodable {
    let County: County
    struct County: Decodable {
        let FIPS: String
    }
}

extension CoordinatesConvertible {
    func fetchFIPS(_ process: @escaping (Int?) -> Void) {
        guard let coord = coordinates
            , let url = URL(string: "https://geo.fcc.gov/api/census/block/find?format=json"
                + "&latitude=\(coord.lat)"
                + "&longitude=\(coord.lng)"
            ) else { return process(nil) }
        let task = URLSession.shared.dataTask(with: url) { (data, _, _) in
            guard let data = data
                , let json = try? JSONDecoder().decode(FIPSWrapper.self, from: data)
                , let fips = Int(json.County.FIPS)
                else { return process(nil) }
            process(fips)
        }
        task.resume()
    }
}
