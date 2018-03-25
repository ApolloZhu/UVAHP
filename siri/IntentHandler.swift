//
//  IntentHandler.swift
//  siri
//
//  Created by Elizabeth Louie on 3/25/18.
//  Copyright © 2018 UVAHP. All rights reserved.
//

import Intents

// As an example, this class is set up to handle Message intents.
// You will want to replace this or add other intents as appropriate.
// The intents you wish to handle must be declared in the extension's Info.plist.

// You can test your example integration by saying things to Siri like:
// "Send a message using EyeAlert"
// "EyeAlert John saying hello"
// "Search for messages in EyeAlert"

let cancelKeywords = ["result", "ok", "resolved", "stop", "give up", "done", "nevermind", "never mind", "cancel"]

extension INPerson {
    convenience init(name: String) {
        self.init(personHandle: INPersonHandle(value: name, type: .unknown), nameComponents: nil, displayName: name, image: nil, contactIdentifier: nil, customIdentifier: nil, aliases: nil, suggestionType: .instantMessageAddress)
    }

    static let police = INPerson(name: "Police")
    static let fire = INPerson(name: "Fire Department")
    static let medical = INPerson(name: "Ambulance")
    static let everyone = INPerson(name: "All Services")

    static let allKeywords = ["all", "service", "services", "departments", "every", "any", "everyone", "every body", "any body", "anyone", "all services", "all service"]
    static let policeKeywords = ["police", "policeman", "policewoman", "policemen", "policewomen"]
    static let fireKeywords = ["fire", "firefighter", "smoke", "fireman", "firewoman", "water", "extinguisher", "ash"]
    static let medicalKeywords = ["ambulance", "medical", "medication", "medicine", "hurt", "fall", "cure"]

    static func matching(_ words: String?...) -> INPerson? {
        for case let .some(word) in words {
            let lowercase = word.lowercased()
            for keyword in allKeywords {
                if lowercase.contains(keyword) {
                    return everyone
                }
            }
            for keyword in policeKeywords {
                if lowercase.contains(keyword) {
                    return police
                }
            }
            for keyword in fireKeywords {
                if lowercase.contains(keyword) {
                    return fire
                }
            }
            for keyword in medicalKeywords {
                if lowercase.contains(keyword) {
                    return medical
                }
            }
        }
        return nil
    }
}

class IntentHandler: INExtension, INSendMessageIntentHandling, INSearchForMessagesIntentHandling, INSetMessageAttributeIntentHandling {
    let manager = CLLocationManager()
    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        return self
    }
    
    // MARK: - INSendMessageIntentHandling

    let allPersonResults: [INPersonResolutionResult] = [
        .success(with: .police), .success(with: .fire), .success(with: .medical)
    ]
    
    // Implement resolution methods to provide additional information about your intent (optional).
    func resolveRecipients(for intent: INSendMessageIntent, with completion: @escaping ([INPersonResolutionResult]) -> Void) {
        guard let recipients = intent.recipients
            , recipients.count != 0
            else {
                if let content = intent.content {
                    var resolutionResults: Set<INPersonResolutionResult> = []
                    for word in content.components(separatedBy: .whitespaces) {
                        if let person = INPerson.matching(word) {
                            resolutionResults.insert(.success(with: person))
                        }
                    }
                    if resolutionResults.count == 0 {
                        return completion(allPersonResults)
                    } else {
                        return completion(Array(resolutionResults))
                    }
                } else {
                    return completion(allPersonResults)
                }
        }
        var resolutionResults: Set<INPersonResolutionResult> = []
        for recipient in recipients {
            let comp = recipient.nameComponents
            if let person = INPerson.matching(
                recipient.displayName,
                intent.content,
                comp?.nickname,
                comp?.familyName,
                comp?.givenName) {
                if person == .everyone {
                    return completion(allPersonResults)
                }
                resolutionResults.insert(.success(with: person))
            }
        }
        if resolutionResults.count == 0 {
            return completion(allPersonResults)
        } else {
            return completion(Array(resolutionResults))
        }
    }
    
    func resolveContent(for intent: INSendMessageIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let text = intent.content, !text.isEmpty {
            return completion(.success(with: text))
        } else {
            return completion(.success(with: "Help!"))
        }
    }
    
    // Once resolution is completed, perform validation on the intent and provide confirmation (optional).
    
    func confirm(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        // Verify user is authenticated and your app is ready to send a message.
        if nil == manager.location || !SafeTrekManager.shared.isLoggedIn {
            return completion(.init(code: .failure, userActivity: nil))
        } else {
            let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
            let response = INSendMessageIntentResponse(code: .ready, userActivity: userActivity)
            return completion(response)
        }
    }
    
    // Handle the completed intent (required).
    
    func handle(intent: INSendMessageIntent, completion: @escaping (INSendMessageIntentResponse) -> Void) {
        // Cancel
        if let comp = intent.content?.lowercased().components(separatedBy: .whitespaces) {
            for word in comp {
                for keyword in cancelKeywords {
                    if word.contains(keyword) {
                        SafeTrekManager.shared.cancel()
                        return completion(.init(code: .success, userActivity: nil))
                    }
                }
            }
        }
        // Alert
        let services: Services
        if let people = intent.recipients, people.count > 0 {
            services = Services(
                police: people.contains(.police),
                fire: people.contains(.fire),
                medical: people.contains(.medical)
            )
        } else {
            services = Services(police: true, fire: true, medical: true)
        }
        guard let loc = manager.location else {
            return completion(.init(code: .failure, userActivity: nil))
        }
        if SafeTrekManager.shared.isActive {
            SafeTrekManager.shared.updateLocation(to: loc)
            showNotification(
                title: "Updated",
                message: "Hang in there!",
                soundName: "Ping.aiff"
            )
        } else {
            SafeTrekManager.shared.triggerAlarm(services: services, location: loc)
        }
        let userActivity = NSUserActivity(activityType: NSStringFromClass(INSendMessageIntent.self))
        let response = INSendMessageIntentResponse(
            code: .success, userActivity: userActivity
        )
        return completion(response)
    }
    
    // Implement handlers for each intent you wish to handle.  As an example for messages, you may wish to also handle searchForMessages and setMessageAttributes.
    
    // MARK: - INSearchForMessagesIntentHandling
    
    func handle(intent: INSearchForMessagesIntent, completion: @escaping (INSearchForMessagesIntentResponse) -> Void) {
        return completion(.init(code: .failure, userActivity: nil))
    }
    
    // MARK: - INSetMessageAttributeIntentHandling
    
    func handle(intent: INSetMessageAttributeIntent, completion: @escaping (INSetMessageAttributeIntentResponse) -> Void) {
        // Implement your application logic to set the message attribute here.
        return completion(.init(code: .failure, userActivity: nil))
    }
}

