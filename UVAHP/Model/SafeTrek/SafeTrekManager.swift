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
import UserNotifications

class SafeTrekManager {
    private init() { }
    public static let shared = SafeTrekManager()
}
extension SafeTrekManager {
    public var isLoggedIn: Bool {
        return accessToken != nil
    }
    
    public var accessToken: String? {
        get { return UserDefaults.standard.string(forKey: "accessToken") }
        set { UserDefaults.standard.set(newValue, forKey: "accessToken") }
    }
    
    public func login() {
        let string = "https://account-sandbox.safetrek.io/authorize?"
            + "client_id=m5qXF5ztOdT4cdQtUbZT2grBhF187vw6&"
            + "scope=openid phone offline_access&"
            // + "state=<state_string>&"
            + "response_type=code&"
            + "redirect_uri=https://uvahp.herokuapp.com/callback"
        let url = string
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        UIApplication.shared.open(URL(string: url!)!)
    }
    
    private func makePostRequest(to url: URL, jsonData: Data) -> URLRequest {
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
    public func triggerAlarm(services: Services, location: CoordinatesConvertible & AddressConvertible) {
        triggerAlarm(services: services,
                     location: location.coordinates ?? location.address)
    }
    
    public func triggerAlarm(services: Services, location: AddressConvertible) {
        triggerAlarm(services: services, location: location.address)
    }
    
    public func triggerAlarm(services: Services, location: CoordinatesConvertible) {
        triggerAlarm(services: services, location: location.coordinates)
    }
    
    public func triggerAlarm(services: Services, location: CodableLocation) {
        print("Trigger")
        guard !isActive else { return updateLocation(to: location) }
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
                else {
                    return UIApplication.shared.open(URL(string: "telprompt:911")!)
            }
            self.activeAlarm = extractor.id
            let center = UNUserNotificationCenter.current()
            let content = UNMutableNotificationContent()
            content.title = "Incident Reported!"
            content.body = "Be claim and wait for furthur instructions!"
            let cancel = UNNotificationAction(identifier: "cancel", title: "Cancel", options: .destructive)
            let category = UNNotificationCategory.init(identifier: "Category", actions: [cancel], intentIdentifiers: [], options: [])
            center.setNotificationCategories([category])
            content.categoryIdentifier = "Category"
            let request = UNNotificationRequest(
                identifier: "Submitted", content: content, trigger: nil
            )
            center.add(request, withCompletionHandler: nil)
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
    public var isActive: Bool {
        return activeAlarm != nil
    }
    
    private var activeAlarm: String! {
        get { return UserDefaults.standard.string(forKey: "activeAlarm") }
        set { UserDefaults.standard.set(newValue, forKey: "activeAlarm") }
    }
}

extension SafeTrekManager {
    public func updateLocation(to newLocation: CoordinatesConvertible & AddressConvertible) {
        updateLocation(to: newLocation.coordinates ?? newLocation.address)
    }
    
    public func updateLocation(to newLocation: CoordinatesConvertible) {
        updateLocation(to: newLocation.coordinates)
    }
    
    public func updateLocation(to newLocation: AddressConvertible) {
        updateLocation(to: newLocation.address)
    }
    
    public func updateLocation(to newLocation: CodableLocation) {
        guard isActive else { return }
        let path = "https://api.safetrek.io/v1/alarms/\(activeAlarm!)/locations"
        let data: Data?
        switch newLocation {
        case let coord as Coordinates:
            struct Wrapper: Encodable {
                let coordinates: Coordinates
            }
            data = try? JSONEncoder().encode(Wrapper(coordinates: coord))
        case let addr as Address:
            struct Wrapper: Encodable {
                let address: Address
            }
            data = try? JSONEncoder().encode(Wrapper(address: addr))
        default: fatalError("Unsupported Type")
        }
        guard let url = URL(string: path)
            , let jsonData = data
            else { return showError("Failed to update.") }
        let request = makePostRequest(to: url, jsonData: jsonData)
        URLSession.shared.dataTask(with: request).resume()
    }
}

extension SafeTrekManager {
    public func cancel() {
        guard isActive else { return }
        let dict = ["status": "CANCELED"]
        let path = "https://api.safetrek.io/v1/alarms/\(activeAlarm!)/status"
        activeAlarm = nil
        guard let url = URL(string: path)
            , let data = try? JSONEncoder().encode(dict)
            else { return showError("Failed to cancel.") }
        let request = makePostRequest(to: url, jsonData: data)
        URLSession.shared.dataTask(with: request).resume()
    }
}
