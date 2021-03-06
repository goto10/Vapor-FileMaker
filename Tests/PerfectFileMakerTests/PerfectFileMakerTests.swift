import XCTest
@testable import FileMakerConnector

let testHost = "127.0.0.1"
let testPort = 80
let testUserName = ""
let testPassword = ""
let sampleDB = "FMServer_Sample"
let sampleLayout = "Task Details"

class PerfectFileMakerTests: XCTestCase {
	
	func getServer() -> FileMakerServer {
		return FileMakerServer(host: testHost, port: testPort, userName: testUserName, password: testPassword)
	}
	
	func testDatabaseNames() {
		let expect = self.expectation(description: "done")
		let fms = getServer()
		
		fms.databaseNames {
			result in
			defer {
				expect.fulfill()
			}
			do {
				let names = try result()
				XCTAssert(names.contains(sampleDB))
			} catch FMPError.serverError(let code, let msg) {
				return XCTAssert(false, "\(code) \(msg)")
			} catch let e {
				return XCTAssert(false, "\(e)")
			}
		}
		
		self.waitForExpectations(timeout: 60.0) {
			_ in
			
		}
	}
	
	func testLayoutNames() {
		let expect = self.expectation(description: "done")
		let fms = getServer()
		
		fms.layoutNames(database: sampleDB) {
			result in
			defer {
				expect.fulfill()
			}
			guard let names = try? result() else {
				return XCTAssert(false, "\(result)")
			}
			XCTAssert(names.contains(sampleLayout))
		}
		
		self.waitForExpectations(timeout: 60.0) {
			_ in
			
		}
	}
	
	func testLayoutInfo() {
		let expectedNames = ["Status", "Category", "Description", "Task", "Related | Sort Selection",
		                     "Days Till Due", "Due Date", "Assignees::Name", "Assignees::Phone",
		                     "Assignees::Email", "Attachments::Attachment | Container",
		                     "Attachments::Comments", "Related Tasks::Task",
		                     "Related Tasks::Due Date", "Related Tasks::Description"]
		
		let expect = self.expectation(description: "done")
		let fms = getServer()
		
		fms.layoutInfo(database: sampleDB, layout: sampleLayout) {
			result in
			defer {
				expect.fulfill()
			}
			guard let layoutInfo = try? result() else {
				return XCTAssert(false, "\(result))")
			}
			let fieldsByName = layoutInfo.fieldsByName
			for expectedField in expectedNames {
				let fnd = fieldsByName[expectedField]
				XCTAssert(nil != fnd)
			}
		}
		
		self.waitForExpectations(timeout: 60.0) {
			_ in
			
		}
	}
	
	func testQuerySkipMax() {
		
		let expect = self.expectation(description: "done")
		let fms = getServer()
		
		func maxZero() {
			let query = FMPQuery(database: sampleDB, layout: sampleLayout, action: .findAll).maxRecords(0)
			XCTAssert("-db=FMServer_Sample&-lay=Task%20Details&-skip=0&-max=0&-findall" == "\(query)")
			fms.query(query) {
				result in
				guard let resultSet = try? result() else {
					XCTAssert(false, "\(result))")
					return expect.fulfill()
				}
				let records = resultSet.records
				let recordCount = records.count
				XCTAssert(recordCount == 0)
				maxTwo()
			}
		}
		
		func maxTwo() {
			let query = FMPQuery(database: sampleDB, layout: sampleLayout, action: .findAll).skipRecords(2).maxRecords(2)
			XCTAssert("-db=FMServer_Sample&-lay=Task%20Details&-skip=2&-max=2&-findall" == "\(query)")
			fms.query(query) {
				result in
				guard let resultSet = try? result() else {
					XCTAssert(false, "\(result))")
					return expect.fulfill()
				}
				let records = resultSet.records
				let recordCount = records.count
				XCTAssert(recordCount == 2)
				expect.fulfill()
			}
		}
		
		maxZero()
		
		self.waitForExpectations(timeout: 60.0) {
			_ in
			
		}
	}
	
	func testQueryFindAll() {
		let query = FMPQuery(database: sampleDB, layout: sampleLayout, action: .findAll)
		let expect = self.expectation(description: "done")
		let fms = getServer()
		
		fms.query(query) {
			result in
			defer {
				expect.fulfill()
			}
			guard let resultSet = try? result() else {
				return XCTAssert(false, "\(result))")
			}
			let fields = resultSet.layoutInfo.fields
			let records = resultSet.records
			let recordCount = records.count
			XCTAssert(recordCount > 0)
			for i in 0..<recordCount {
				let rec = records[i]
				for field in fields {
					switch field {
					case .fieldDefinition(let def):
						let name = def.name
						let fnd = rec.elements[name]
						XCTAssert(nil != fnd, "\(name) not found in \(rec.elements)")
						guard case .field(let fn, _) = fnd! else {
							XCTAssert(false, "expected field \(fnd)")
							continue
						}
						XCTAssert(fn == name)
					case .relatedSetDefinition(let name, let defs):
						let fnd = rec.elements[name]
						XCTAssert(nil != fnd, "\(name) not found in \(rec.elements)")
						guard case .relatedSet(let fn, let relatedRecs) = fnd! else {
							XCTAssert(false, "expected relatedSet \(fnd)")
							continue
						}
						XCTAssert(fn == name)
						let defNames = defs.map { $0.name }
						for relatedRec in relatedRecs {
							for relatedRow in relatedRec.elements.values {
								guard case .field(let fn, _) = relatedRow else {
									XCTAssert(false)
									continue
								}
								XCTAssert(defNames.contains(fn), "strange field name \(fn)")
							}
						}
					}
				}
			}
		}
		
		self.waitForExpectations(timeout: 60.0) {
			_ in
			
		}
	}
	
	func testQueryFindInProgress() {
		
		let qfields = [FMPQueryFieldGroup(fields: [FMPQueryField(name: "Status", value: "In Progress")])]
		let query = FMPQuery(database: sampleDB, layout: sampleLayout, action: .find).queryFields(qfields)
		XCTAssert("-db=FMServer_Sample&-lay=Task%20Details&-skip=0&-max=all&-query=(q1)&-q1=Status&-q1.value===In%20Progress*&-findquery" == "\(query)")
		let expect = self.expectation(description: "done")
		let fms = getServer()
		
		fms.query(query) {
			result in
			defer {
				expect.fulfill()
			}
			guard let resultSet = try? result() else {
				return XCTAssert(false, "\(result))")
			}
			let fields = resultSet.layoutInfo.fields
			let records = resultSet.records
			let recordCount = records.count
			XCTAssert(recordCount > 0)
			for i in 0..<recordCount {
				let rec = records[i]
				for field in fields {
					switch field {
					case .fieldDefinition(let def):
						let name = def.name
						let fnd = rec.elements[name]
						XCTAssert(nil != fnd, "\(name) not found in \(rec.elements)")
						guard case .field(let fn, let fieldValue) = fnd! else {
							XCTAssert(false, "expected field \(fnd)")
							continue
						}
						XCTAssert(fn == name)
						
						if name == "Status" {
							guard case .text(let tstStr) = fieldValue else {
								XCTAssert(false, "bad value \(fieldValue)")
								continue
							}
							XCTAssert("In Progress" == tstStr, "\(tstStr)")
						}
					case .relatedSetDefinition(let name, let defs):
						let fnd = rec.elements[name]
						XCTAssert(nil != fnd, "\(name) not found in \(rec.elements)")
						guard case .relatedSet(let fn, let relatedRecs) = fnd! else {
							XCTAssert(false, "expected relatedSet \(fnd)")
							continue
						}
						XCTAssert(fn == name)
						let defNames = defs.map { $0.name }
						for relatedRec in relatedRecs {
							for relatedRow in relatedRec.elements.values {
								guard case .field(let fn, _) = relatedRow else {
									XCTAssert(false)
									continue
								}
								XCTAssert(defNames.contains(fn), "strange field name \(fn)")
							}
						}
					}
				}
			}
		}
		
		self.waitForExpectations(timeout: 60.0) {
			_ in
			
		}
	}
	
	func testNewAndDelete() {
		let unique = time(nil)
		let task = "Add a new record @ \(unique) ☃️"
		let qfields = [FMPQueryField(name: "Task", value: task), FMPQueryField(name: "Status", value: "In Progress")]
		let query = FMPQuery(database: sampleDB, layout: sampleLayout, action: .new).queryFields(qfields)
		XCTAssert("-db=FMServer_Sample&-lay=Task%20Details&Task=Add%20a%20new%20record%20@%20\(unique)%20%E2%98%83%EF%B8%8F&Status=In%20Progress&-new" == "\(query)")
		let expect = self.expectation(description: "done")
		let fms = getServer()
		
		fms.query(query) {
			result in
			guard let resultSet = try? result() else {
				XCTAssert(false, "\(result))")
				return expect.fulfill()
			}
			XCTAssert(resultSet.records.count == 0)
			let findQuery = FMPQuery(database: sampleDB, layout: sampleLayout, action: .find).queryFields([FMPQueryField(name: "Task", value: task, op: .equal)])
			XCTAssert("-db=FMServer_Sample&-lay=Task%20Details&-skip=0&-max=all&-query=(q1)&-q1=Task&-q1.value===Add%20a%20new%20record%20@%20\(unique)%20%E2%98%83%EF%B8%8F&-findquery" == "\(findQuery)")
			fms.query(findQuery) {
				result in
				guard let resultSet = try? result() else {
					XCTAssert(false, "\(result))")
					return expect.fulfill()
				}
				XCTAssert(resultSet.records.count == 1)
				let recId = resultSet.records.first!.recordId
				XCTAssert(recId != fmpNoRecordId)
				let query = FMPQuery(database: sampleDB, layout: sampleLayout, action: .find).recordId(recId)
				print("\(query)")
				fms.query(query) {
					result in
					guard let resultSet = try? result() else {
						XCTAssert(false, "\(result))")
						return expect.fulfill()
					}
					XCTAssert(resultSet.records.count == 1)
					let recId = resultSet.records.first!.recordId
					XCTAssert(recId != fmpNoRecordId)
					let query = FMPQuery(database: sampleDB, layout: sampleLayout, action: .delete).recordId(recId)
					fms.query(query) {
						result in
						guard let resultSet = try? result() else {
							return XCTAssert(false, "\(result))")
						}
						XCTAssert(resultSet.records.count == 0)
						fms.query(findQuery) {
							result in
							defer {
								expect.fulfill()
							}
							guard let resultSet = try? result() else {
								XCTAssert(false, "\(result))")
								return expect.fulfill()
							}
							XCTAssert(resultSet.records.count == 0)
						}
					}
				}
			}
		}
		
		self.waitForExpectations(timeout: 60.0) {
			_ in
			
		}
	}
	
    static var allTests : [(String, (PerfectFileMakerTests) -> () throws -> Void)] {
		return [
			("testDatabaseNames", testDatabaseNames),
			("testLayoutNames", testLayoutNames),
			("testLayoutInfo", testLayoutInfo),
			("testQuerySkipMax", testQuerySkipMax),
			("testQueryFindAll", testQueryFindAll),
			("testQueryFindInProgress", testQueryFindInProgress),
			("testNewAndDelete", testNewAndDelete),
        ]
    }
}
