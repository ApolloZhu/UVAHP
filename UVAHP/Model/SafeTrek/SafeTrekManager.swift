//
//  SafeTrekManager.swift
//  UVAHP
//
//  Created by Apollo Zhu on 3/24/18.
//  Copyright © 2018 UVAHP. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation

class SafeTrekManager {
    private init() { }
    public static let shared = SafeTrekManager()
}
extension SafeTrekManager {
    public func login() {
        let string = "https://account-sandbox.safetrek.io/authorize?"
            + "client_id=m5qXF5ztOdT4cdQtUbZT2grBhF187vw6&"
            + "scope=openid phone offline_access&"
            // + "state=<state_string>&"
            + "response_type=code&"
            + "redirect_uri=https://uvahp.herokuapp.com/callback"
        let url = string
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        UIApplication.shared.open(URL(string: url!)!
            , options: [:], completionHandler: nil)
    }
}

extension SafeTrekManager {
    public var accessToken: String? {
        get { return UserDefaults.standard.string(forKey: "accessToken") }
        set { UserDefaults.standard.set(newValue, forKey: "accessToken") }
    }

    func makePostRequest(to url: URL, jsonData: Data) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpBody = jsonData
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken ?? "")",
            forHTTPHeaderField: "Authorization")
        request.addValue("application/json",
                         forHTTPHeaderField: "Content-Type")
        return request
    }
}

extension SafeTrekManager {
    public func triggerAlarm(services: Services, location: LocationConvertible) {
        triggerAlarm(services: services, location: location.coordinates)
    }

    public func triggerAlarm(services: Services, location: CodableLocation) {
        let alarm = Alarm(services: services, location: location)
        guard let data = try? JSONEncoder().encode(alarm)
            , let url = URL(string: "https://api-sandbox.safetrek.io/v1/alarms")
            else { return }
        let request = makePostRequest(to: url, jsonData: data)
        let task = URLSession.shared.dataTask(with: request) { (data, res, err) in
            struct IDExtractor: Decodable { let id: String }
            guard let data = data
                , let extractor = try? JSONDecoder()
                    .decode(IDExtractor.self, from: data)
                else { fatalError("Failed Create Alarm") }
            self.activeAlarm = extractor.id
        }
        task.resume()
    }
}

struct Services: Codable {
    let police: Bool
    let fire: Bool
    let medical: Bool
}

protocol Location { }
typealias CodableLocation = Location & Codable

struct Coordinates: CodableLocation {
    let lat: Double
    let lng: Double
    var accuracy: Int
}

protocol LocationConvertible {
    var coordinates: Coordinates { get }
}

extension CLLocationCoordinate2D: LocationConvertible {
    var coordinates: Coordinates {
        return Coordinates.init(lat: latitude, lng: longitude, accuracy: 0)
    }
}

extension CLLocation: LocationConvertible {
    var coordinates: Coordinates {
        var coord = coordinate.coordinates
        coord.accuracy = Int(
            sqrt(pow(horizontalAccuracy, 2)
            + pow(verticalAccuracy, 2))
        )
        return coord
    }
}

struct Address: CodableLocation {
    let line1: String
    let line2: String
    let city: String
    let state: String
    let zip: String
}

struct Alarm {
    let services: Services
    let location: CodableLocation
}

extension Alarm: Codable {
    enum CodingKeys: String, CodingKey {
        case services
        case coordinates = "location.coordinates"
        case address = "location.address"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(services, forKey: .services)
        if let coordinates = location as? Coordinates {
            try container.encode(coordinates, forKey: .coordinates)
        } else if let address = location as? Address {
            try container.encode(address, forKey: .address)
        } else { throw Exception() }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        services = try container.decode(Services.self, forKey: .services)
        if let loc = try? container
            .decode(Coordinates.self, forKey: .coordinates) {
            location = loc
        } else if let loc = try? container
            .decode(Address.self, forKey: .address) {
            location = loc
        } else { throw Exception() }
    }
}

extension SafeTrekManager {
    public var activeAlarm: String? {
        get { return UserDefaults.standard.string(forKey: "activeAlarm") }
        set { UserDefaults.standard.set(newValue, forKey: "activeAlarm") }
    }
}

extension SafeTrekManager {
    public func cancel() {
        let dict = ["status": "CANCELED"]
        let path = "https://api.safetrek.io/v1/alarms/\(activeAlarm ?? "")/status"
        guard let url = URL(string: path)
            , let data = try? JSONEncoder().encode(dict)
            else { return }
        let request = makePostRequest(to: url, jsonData: data)
        URLSession.shared.dataTask(with: request).resume()
    }
}
