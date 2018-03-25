//
//  CoreLocation+Extensions.swift
//  UVAHP
//
//  Created by Apollo Zhu on 3/25/18.
//  Copyright © 2018 UVAHP. All rights reserved.
//

import Foundation
import CoreLocation

protocol Location { }

typealias CodableLocation = Location & Codable

struct Coordinates: CodableLocation {
    let lat: Double
    let lng: Double
    var accuracy: Int
}

protocol CoordinatesConvertible {
    var coordinates: Coordinates! { get }
}

struct Address: CodableLocation {
    let line1: String
    let line2: String
    let city: String
    let state: String
    let zip: String
}

protocol AddressConvertible {
    var address: Address! { get }
}

extension CLLocationCoordinate2D: CoordinatesConvertible {
    var coordinates: Coordinates! {
        return Coordinates(lat: latitude, lng: longitude, accuracy: 0)
    }
}

extension CLLocation: CoordinatesConvertible {
    var coordinates: Coordinates! {
        var coord = coordinate.coordinates!
        coord.accuracy = Int(
            sqrt(pow(horizontalAccuracy, 2)
                + pow(verticalAccuracy, 2))
        )
        return coord
    }
}

extension CLLocation {
    var placemark: CLPlacemark? {
        var result: CLPlacemark? = nil
        let group = DispatchGroup()
        group.enter()
        CLGeocoder().reverseGeocodeLocation(self) { (marks, err) in
            result = marks?.first
            group.leave()
        }
        group.wait()
        return result
    }
}

extension CLPlacemark: CoordinatesConvertible, AddressConvertible {
    var coordinates: Coordinates! {
        return location?.coordinates
    }
    
    var address: Address! {
        let info = [thoroughfare, subThoroughfare, locality, administrativeArea, postalCode]
        guard info.first(where: { $0 != nil }) != nil else { return nil }
        return Address(
            line1: info[0] ?? "",
            line2: info[1] ?? "",
            city: info[2] ?? "",
            state: info[3] ?? "",
            zip: info[4] ?? ""
        )
    }
}
