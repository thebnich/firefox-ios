/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

import UIKit
import XCTest

let ExpectedEngines = ["Amazon.com", "Bing", "DuckDuckGo", "Google", "Twitter", "Wikipedia", "Yahoo"]

class SearchTests: XCTestCase {
    func testParsing() {
        let parser = OpenSearchParser(pluginMode: true)
        let file = NSBundle.mainBundle().pathForResource("google", ofType: "xml", inDirectory: "Locales/en-US/searchplugins")
        let engine: OpenSearchEngine! = parser.parse(file!)
        XCTAssertEqual(engine.shortName, "Google")
        XCTAssertNil(engine.description)

        // Test regular search queries.
        XCTAssertEqual(engine.searchURLForQuery("foobar")!.absoluteString!, "https://www.google.com/search?q=foobar&ie=utf-8&oe=utf-8")

        // Test search suggestion queries.
        XCTAssertEqual(engine.suggestURLForQuery("foobar")!.absoluteString!, "https://www.google.com/complete/search?client=firefox&q=foobar")
    }

    func testSearchEngines() {
        let engines = SearchEngines().list
        XCTAssertEqual(engines.count, ExpectedEngines.count)

        for i in 0 ..< engines.count {
            let engine = engines[i]
            XCTAssertEqual(engine.shortName, ExpectedEngines[i])
        }
    }

    // TODO: Use a mock HTTP server instead.
    func testSuggestClient() {
        let parser = OpenSearchParser(pluginMode: true)
        let file = NSBundle.mainBundle().pathForResource("google", ofType: "xml", inDirectory: "Locales/en-US/searchplugins")
        let engine: OpenSearchEngine! = parser.parse(file!)
        let client = SearchSuggestClient(searchEngine: engine)

        let expectation = self.expectationWithDescription("Response received")

        client.query("foobar", callback: { response, error in
            if error != nil {
                XCTFail("Error: \(error?.description)")
            }

            // TODO: This test is especially fragile since the suggestions list may change at any time.
            // Check just the first few results since they're likely more stable.
            XCTAssertEqual(response![0], "foobar")
            XCTAssertEqual(response![1], "foobar2000 mac")
            XCTAssertEqual(response![2], "foobar skins")

            expectation.fulfill()
        })

        waitForExpectationsWithTimeout(10, handler: nil)
    }
}