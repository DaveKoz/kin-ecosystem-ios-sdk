//
//  RestClient.swift
//  KinEcosystem
//
//  Created by Elazar Yifrach on 22/02/2018.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import Foundation
import AdSupport
import KinUtil

enum EcosystemNetError: Error {
    case network(Error)
    case serviceError(ResponseError)
    case requestBuild
    case noDataInResponse
    case responseParseError
    case unknown
}

class RestClient {
    
    fileprivate var config: EcosystemConfiguration
    lazy var signInData: SignInData = {
        
        let displayName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ?? "unknwon"
        var identifier = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        let letters = NSCharacterSet.letters
        if identifier.rangeOfCharacter(from: letters) == nil {
            if let vendorIdentifier = UIDevice.current.identifierForVendor?.uuidString {
                identifier = vendorIdentifier
            } else if let uuid = UserDefaults.standard.string(forKey: "ecosystemUUID") {
                identifier = uuid
            } else {
                let uuid = UUID().uuidString
                UserDefaults.standard.set(uuid, forKey: "ecosystemUUID")
                identifier = uuid
            }
        }
        return SignInData(jwt: config.jwt ?? nil,
                          user_id: config.userId,
                          app_id: displayName,
                          device_id: identifier,
                          public_address: config.publicAddress,
                          sign_in_type: config.jwt != nil ? SignInType.jwt.rawValue : SignInType.whitelist.rawValue)
    }()
    
    fileprivate var lastToken: AuthToken?
    var authToken: AuthToken? {
        get {
            if lastToken != nil {
                return lastToken
            }
            if  let tokenJson = UserDefaults.standard.string(forKey: "authToken"),
                let data = tokenJson.data(using: .utf8),
                let token = try? JSONDecoder().decode(AuthToken.self, from: data),
                let expiryDate = Iso8601DateFormatter.date(from: token.expiration_date),
                Date().compare(expiryDate) == .orderedAscending {
                lastToken = token
                return token
            }
            return nil
        }
        set {
            guard newValue != nil else {
                lastToken = nil
                UserDefaults.standard.removeObject(forKey: "authToken")
                return
            }
            if  let tokenData = try? JSONEncoder().encode(newValue),
                let tokenString = String(data: tokenData, encoding: .utf8) {
                lastToken = newValue
                UserDefaults.standard.set(tokenString, forKey: "authToken")
            }
        }
    }
    
    init(_ config: EcosystemConfiguration) {
        self.config = config
    }
    
    func buildRequest(path: String, method: HTTPMethod, contentType: ContentType = .json, body: Data? = nil, parameters: [String: String]? = nil) -> Promise<URLRequest> {
        
        let p = Promise<URLRequest>()
        guard var urlComponents = URLComponents(url: config.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            logError("building request failed: (\(path), \(method), \(String(describing: body)), \(String(describing: parameters))")
            return p.signal(EcosystemNetError.requestBuild)
        }
        if let parameters = parameters {
            urlComponents.queryItems = parameters.map({ (key, value) in
                URLQueryItem(name: key, value: value)
            })
        }
        guard let url = urlComponents.url else {
            logError("url invalid: (\(path), \(method), \(String(describing: body)), \(String(describing: parameters))")
            return p.signal(EcosystemNetError.requestBuild)
        }
        var request = URLRequest(url: url)
        
        if let body = body {
            request.httpBody = body
        }
        
        request.httpMethod = method.rawValue
        
        if let auth = authToken {
            request.addValue("Bearer \(auth.token)", forHTTPHeaderField: "Authorization")
        }
        
        request.addValue(contentType.rawValue, forHTTPHeaderField: "content-type")
        request.addValue(UUID().uuidString, forHTTPHeaderField: "X-REQUEST-ID")
        
        return p.signal(request)
        
    }
    
    // request with a data result
    func dataRequest(_ request: URLRequest) -> Promise<Data> {
        let p = Promise<Data>()
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                logError("request \(String(describing: request.url?.absoluteString)) failed, network error: \(error)")
                p.signal(EcosystemNetError.network(error))
                return
            }
            guard let data = data else {
                logError("request \(String(describing: request.url?.absoluteString)) failed, no data received")
                p.signal(EcosystemNetError.noDataInResponse)
                return
            }
            guard   let response = response as? HTTPURLResponse,
                        response.statusCode == 200 else {
                if let responseError = try? JSONDecoder().decode(ResponseError.self, from: data) {
                    logError("request \(String(describing: request.url?.absoluteString)) failed, service ok but returned \(responseError.code)")
                    p.signal(EcosystemNetError.serviceError(responseError))
                } else {
                    logError("request \(String(describing: request.url?.absoluteString)) failed for unknown reason")
                    p.signal(EcosystemNetError.unknown)
                }
                return
            }
            p.signal(data)
        }.resume()
        return p
    }
    
    // request with a just success result
    func request(_ request: URLRequest) -> Promise<Void> {
        let p = Promise<Void>()
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                p.signal(EcosystemNetError.network(error))
                return
            }
            guard   let response = response as? HTTPURLResponse,
                        response.statusCode == 200 else {
                    if  let data = data,
                        let responseError = try? JSONDecoder().decode(ResponseError.self, from: data) {
                        logError("request \(String(describing: request.url?.absoluteString)) failed, service ok but returned \(responseError.code)")
                        p.signal(EcosystemNetError.serviceError(responseError))
                    } else {
                        logError("request \(String(describing: request.url?.absoluteString)) failed for unknown reason")
                        p.signal(EcosystemNetError.unknown)
                    }
                    return
            }
            p.signal(())
        }.resume()
        return p
    }
    
}