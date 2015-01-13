/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit

private let TypeSearch = "text/html"

private class OpenSearchURL {
    let template: String
    let type: String

    init(template: String, type: String) {
        self.template = template;
        self.type = type;
    }
}

class OpenSearchEngine {
    let shortName: String
    let description: String?
    let image: UIImage?
    private let searchURL: OpenSearchURL

    private init(shortName: String, description: String?, image: UIImage?, searchURL: OpenSearchURL) {
        self.shortName = shortName
        self.description = description
        self.image = image
        self.searchURL = searchURL
    }

    /**
     * Returns the search URL for the given query.
     */
    func searchURLForQuery(query: String) -> NSURL? {
        return getURLFromTemplate(searchURL, query: query)
    }

    private func getURLFromTemplate(openSearchURL: OpenSearchURL, query: String) -> NSURL? {
        let escapedQuery = query.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
        if escapedQuery == nil {
            return nil
        }

        let urlString = openSearchURL.template.stringByReplacingOccurrencesOfString("{searchTerms}", withString: escapedQuery!, options: NSStringCompareOptions.LiteralSearch, range: nil)
        return NSURL(string: urlString)
    }
}

/**
 * OpenSearch XML parser.
 *
 * This parser accepts standards-compliant OpenSearch 1.1 XML documents in addition to
 * the Firefox-specific search plugin format.
 *
 * OpenSearch spec: http://www.opensearch.org/Specifications/OpenSearch/1.1
 */
class OpenSearchParser {
    private let pluginMode = false

    init(pluginMode: Bool) {
        self.pluginMode = pluginMode
    }

    func parse(file: String) -> OpenSearchEngine? {
        let data = NSData(contentsOfFile: file)

        if data == nil {
            println("Invalid search file")
            return nil
        }

        let rootName = pluginMode ? "SearchPlugin" : "OpenSearchDescription"
        let docElement: XMLElement! = SWXMLHash.parse(data!)[rootName][0].element

        if docElement == nil {
            println("Invalid XML document")
            return nil
        }

        let shortNameElement = docElement.elements["ShortName"]
        if shortNameElement?.count != 1 {
            println("ShortName must appear exactly once")
            return nil
        }

        let shortName = shortNameElement![0].text
        if shortName == nil {
            println("ShortName must contain text")
            return nil
        }

        let descriptionElement = docElement.elements["Description"]
        if !pluginMode && descriptionElement?.count != 1 {
            println("Description must appear exactly once")
            return nil
        }
        let description = descriptionElement?[0].text

        var urls = docElement.elements["Url"]
        if urls == nil {
            println("Url must appear at least once")
            return nil
        }

        var searchURL: OpenSearchURL!
        var searchURLs = [OpenSearchURL]()
        for url in urls! {
            let type = url.attributes["type"]
            if type == nil {
                println("Url element requires a type attribute")
                return nil
            }

            if type != TypeSearch {
                // Not a supported search type.
                continue
            }

            var template = url.attributes["template"]
            if template == nil {
                println("Url element requires a template attribute")
                return nil
            }

            if pluginMode {
                var params = url.elements["Param"]

                if params != nil {
                    template! += "?"
                    var firstAdded = false
                    for param in params! {
                        if firstAdded {
                            template! += "&"
                        } else {
                            firstAdded = true
                        }

                        let name = param.attributes["name"]
                        let value = param.attributes["value"]
                        if name == nil || value == nil {
                            println("Param element must have name and value attributes")
                            return nil
                        }
                        template! += name! + "=" + value!
                    }
                }
            }

            let url = OpenSearchURL(template: template!, type: type!)
            if type == TypeSearch {
                searchURL = url
            }
        }

        if searchURL == nil {
            println("Search engine must have a text/html type")
            return nil
        }

        var uiImage: UIImage?
        var images = docElement.elements["Image"]

        for imageDict in images! {
            // TODO: For now, we only look for 16x16 search icons.
            let imageWidth = imageDict.attributes["width"]
            let imageHeight = imageDict.attributes["height"]
            if imageWidth?.toInt() != 16 || imageHeight?.toInt() != 16 {
                continue
            }

            if imageDict.text == nil {
                continue
            }

            let imageURL = NSURL(string: imageDict.text!)
            if let imageURL = imageURL {
                let imageData = NSData(contentsOfURL: imageURL)
                if let imageData = imageData {
                    let image = UIImage(data: imageData)
                    if let image = image {
                        uiImage = image
                    } else {
                        println("Error: Invalid search image data")
                    }
                } else {
                    println("Error: Invalid search image data")
                }
            } else {
                println("Error: Invalid search image data")
            }
        }

        return OpenSearchEngine(shortName: shortName!, description: description, image: uiImage, searchURL: searchURL)
    }
}