//
// FileMakerServer.swift
//
// Created by Mike Anelli - 2017-03-04
//
//===----------------------------------------------------------------------===//
// This file is a port of the Perfect-FileMaker connector.
// Originally Created by Kyle Jessup on 2016-08-03.
// Copyright (C) 2016 PerfectlySoft, Inc.
//===----------------------------------------------------------------------===//

import Foundation
import Vapor
import HTTP
import PerfectXML


extension XNode {
    var childElements: [XElement] {
        return self.childNodes.flatMap { $0 as? XElement }
    }
}

enum FMPGrammar: String {
    case fmResultSet = "fmresultset"
//    case fmpXMLResult = "FMPXMLRESULT"  // Currenlyt only supports fmresultset
}

public enum FMPError: Error {
    /// An error code and message.
    case serverError(Int, String)
}

public struct FileMakerServer {
    
    let host: String
    let port: Int
    let userName: String
    let password: String
    
    // Initialize using a host, port, username and password.
    public init(host: String, port: Int, userName: String, password: String) {
        self.host = host
        self.port = port
        self.userName = userName
        self.password = password
    }
    
    func makeUrl(grammar: FMPGrammar) -> String {
        let scheme = port == 443 ? "https" : "http"
        let url = "\(scheme)://\(host):\(port)/fmi/xml/\(grammar.rawValue).xml"
        return url
    }

    func checkError(doc: XDocument, xpath: String, namespaces: [(String, String)]) -> Int {
    
        guard let errorNode = doc.extractOne(path: xpath, namespaces: namespaces),
            let nodeValue = errorNode.nodeValue,
            let errorCode = Int(nodeValue) else {
                return 500
        }
        
        return errorCode
        
    }
    
    func performRequest(query: String, grammar: FMPGrammar) throws -> FMPResultSet {
        
        let urlString = "\(makeUrl(grammar: grammar))?\(query)"
        
        let loginString = "\(userName):\(password)"
        let b64Login = Data(loginString.utf8).base64EncodedString(options: [])
        
        let drop = Droplet()
        let fmsResponse =  try drop.client.get(urlString, headers: [.authorization : "Basic \(b64Login)"])
        
        guard let responseBytes = fmsResponse.body.bytes else {
            throw ClientError.invalidRequestScheme
        }
        
        guard let xmlString = String(bytes: responseBytes, encoding: String.Encoding.utf8) else {
            throw ClientError.invalidRequestScheme
        }
        
        guard let doc = XDocument(fromSource: xmlString) else {
            throw ClientError.invalidRequestScheme
        }
        
        return try processGrammar_FMPResultSet(doc: doc)
        
    }
    
    func processGrammar_FMPResultSet(doc: XDocument) throws -> FMPResultSet {
        
        let errorCode = checkError(doc: doc, xpath: fmrsErrorCode, namespaces: fmrsNamespaces)
        
        guard errorCode == 0 || errorCode == 200 else {
            throw FMPError.serverError(errorCode, "Error from FileMaker server")
        }
        
        guard let result = FMPResultSet(doc: doc) else {
            throw FMPError.serverError(500, "Invalid response from FileMaker server")
        }
        
        return result
    }
    
    func setToNames(result: FMPResultSet, key: String) throws -> [String] {
        
        var names = [String]()
        
        for rec in result.records {
            guard let field = rec.elements[key],
                case .field(_, let value) = field else {
                    continue
            }
            names.append("\(value)")
        }
        
        return names
        
    }
    
    // Retrieve the list of database hosted by the server.
    public func databaseNames() throws -> JSON {
        
        let fmpResult = try performRequest(query: "-dbnames", grammar: .fmResultSet)
        
        let list = try setToNames(result: fmpResult, key: "DATABASE_NAME")
        let jsonList = try JSON(node: list)
        
        return try JSON(node: ["databases" : jsonList])
        
    }
    
    // Retrieve the list of layouts for a particular database.
    public func layoutNames(database: String) throws -> JSON {
        
        let fmpResult = try performRequest(query: "-db=\(database.stringByEncodingURL)&-layoutnames", grammar: .fmResultSet)
        
        let list = try setToNames(result: fmpResult, key: "LAYOUT_NAME")
        let jsonList = try JSON(node: list)
        
        return try JSON(node: ["layouts" : jsonList])
        
    }
    
    // Get a database's layout information. Includes all field and portal names.
    public func layoutInfo(database: String, layout: String) throws -> JSON {
    
        let fmpResult = try performRequest(query: "-db=\(database.stringByEncodingURL)&-lay=\(layout.stringByEncodingURL)&-view", grammar: .fmResultSet)
        let layoutInfo = fmpResult.layoutInfo
        let fields = layoutInfo.fieldsByName
        
        
        var fieldNameList: [String] = [String]()
        for (fieldName, _) in fields {
           fieldNameList.append(fieldName)
        }

        return try JSON(node: ["fieldNames" : JSON(node: fieldNameList)])
        
    }
    
    // Perform a query and provide any resulting data.
    public func query(_ query: FMPQuery) throws -> JSON {
        
        let queryString = query.queryString
        let fmpResult = try performRequest(query: queryString, grammar: .fmResultSet)
        
        let fields = fmpResult.layoutInfo.fields
        let records = fmpResult.records
        
        var recordList = [Node]()

        for record in records {
            var fieldList = [Node]()
            
            for field in fields {
                switch field {
                
                case .fieldDefinition(let def):
                    let fieldName = def.name
                    if let fnd = record.elements[fieldName], case .field(_, let fieldValue) = fnd {
                        fieldList.append(try [fieldName : fieldValue.description].makeNode())
                    }
                    
                
                case .relatedSetDefinition(let name, _):
                    guard let fnd = record.elements[name], case .relatedSet(_, let relatedRecs) = fnd else {
                        continue
                    }
                    var relatedList = [Node]()
                    for relatedRec in relatedRecs {
                        for relatedRow in relatedRec.elements.values {
                            if case .field(let fieldName, let fieldValue) = relatedRow {
                                relatedList.append(try [fieldName : fieldValue.description].makeNode())
                            }
                        }
                    }
                    
                    fieldList.append( try ["relatedSet" : relatedList.makeNode()] )
                }
            }
            
            recordList.append(try ["record" : fieldList.makeNode()])
            
        }
        
        
        return try JSON(node: recordList.makeNode())
        
    }
    
    
}
