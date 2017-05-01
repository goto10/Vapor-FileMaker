# Perfect - FileMaker Server Connector


<p align="center">
    <a href="https://developer.apple.com/swift/" target="_blank">
        <img src="https://img.shields.io/badge/Swift-3.0-orange.svg?style=flat" alt="Swift 3.0">
    </a>
    <a href="https://developer.apple.com/swift/" target="_blank">
        <img src="https://img.shields.io/badge/Platforms-OS%20X%20%7C%20Linux%20-lightgray.svg?style=flat" alt="Platforms OS X | Linux">
    </a>
    <a href="http://perfect.org/licensing.html" target="_blank">
        <img src="https://img.shields.io/badge/License-Apache-lightgrey.svg?style=flat" alt="License Apache">
    </a>
</p>

This project provides access to FileMaker Server databases using the XML Web publishing interface.

This package is a Vapor port of the [Perfect-FileMaker](https://github.com/PerfectlySoft/Perfect-FileMaker) project. 

Ensure you have installed and activated the latest Swift 3.0 tool chain.

## Linux Build Notes

Ensure that you have installed curl and libxml2.

```
sudo apt-get install libcurl4-openssl-dev libxml2-dev
```

## Building

Add this project as a dependency in your Package.swift file.

```
.Package(url: "https://github.com/goto10/Vapor-FileMaker.git", majorVersion: 1, minor: 0)
```

## Examples

To utilize this package, ```import VaporFileMaker```.
All responses come back as JSON and conform to ResponseRepresentable

### List Available Databases

This snippet connects to the server and has it list all of the hosted databases.

```swift
drop.get("dblist") { request in 
	let fms = FileMakerServer(host: testHost, port: testPort, userName: testUserName, password: testPassword)

	return try fms.databaseNames()

}
```

### List Available Layouts

List all of the layouts in a particular database.

```swift
let fms = FileMakerServer(host: testHost, port: testPort, userName: testUserName, password: testPassword)
let layoutList = try fms.layoutNames(database: dbName)
```

### List Field On Layout

List all of the field names on a particular layout.

```swift
let fms = FileMakerServer(host: testHost, port: testPort, userName: testUserName, password: testPassword)
let layoutInfo = fms.layoutInfo(database: "FMServer_Sample", layout: "Task Details")
```

### Find All Records

Perform a findall and print all field names and values.

```swift
let query = FMPQuery(database: "FMServer_Sample", layout: "Task Details", action: .findAll)
let fms = FileMakerServer(host: testHost, port: testPort, userName: testUserName, password: testPassword)

let results = fms.query(query)

```

### Find All Records With Skip &amp; Max

To add skip and max, the query above would be amended as follows:

```swift
// Skip two records and return a max of two records.
let query = FMPQuery(database: "FMServer_Sample", layout: "Task Details", action: .findAll)
	.skipRecords(2).maxRecords(2)
...
```

### Find Records Where "Status" Is "In Progress"

Find all records where the field "Status" has the value of "In Progress".

```swift
let qfields = [FMPQueryFieldGroup(fields: [FMPQueryField(name: "Status", value: "In Progress")])]
let query = FMPQuery(database: "FMServer_Sample", layout: "Task Details", action: .find)
	.queryFields(qfields)
let fms = FileMakerServer(host: testHost, port: testPort, userName: testUserName, password: testPassword)
let results = fms.query(query)
```
