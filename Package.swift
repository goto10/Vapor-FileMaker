//
//  Package.swift
//  PerfectFileMaker
//
//  Created by Kyle Jessup on 2016-07-20.
//	Copyright (C) 2016 PerfectlySoft, Inc.
//
//	Ported to Vapor by Mike Anelli on 2017-05-01
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2016 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

import PackageDescription

let package = Package(
	name: "FileMakerConnector",
	dependencies: [
		.Package(url: "https://github.com/vapor/vapor.git", majorVersion: 2),
		.Package(url:"https://github.com/PerfectlySoft/Perfect-XML.git", majorVersion: 2, minor: 0)
	]
)
