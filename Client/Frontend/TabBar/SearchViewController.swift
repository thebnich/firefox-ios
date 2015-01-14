/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit

private let ReuseIdentifier = "cell"
private let SuggestionsLimitCount = 3

protocol SearchViewControllerDelegate: class {
    func didClickSearchResult(url: NSURL)
}

class SearchViewController: UIViewController {
    weak var delegate: SearchViewControllerDelegate?
    private var tableView = UITableView()
    private var sortedEngines = [OpenSearchEngine]()
    private var suggestClient: SearchSuggestClient?
    private var searchSuggestions = [String]()

    var searchEngines: SearchEngines? {
        didSet {
            if let searchEngines = searchEngines {
                // Show the default search engine first.
                sortedEngines = searchEngines.list.sorted { engine, _ in engine === searchEngines.defaultEngine }
                suggestClient = SearchSuggestClient(searchEngine: searchEngines.defaultEngine)
            } else {
                sortedEngines = []
                suggestClient = nil
            }
            requerySuggestClient()
            tableView.reloadData()
        }
    }

    var searchQuery: String = "" {
        didSet {
            requerySuggestClient()
            tableView.reloadData()
        }
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init() {
        // The empty initializer of UIViewController creates the class twice (?!),
        // so override it here to avoid calling it.
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.registerClass(SearchTableViewCell.self, forCellReuseIdentifier: ReuseIdentifier)

        // Make the row separators span the width of the entire table.
        tableView.layoutMargins = UIEdgeInsetsZero
        tableView.separatorInset = UIEdgeInsetsZero

        view.addSubview(tableView)
        tableView.snp_makeConstraints { make in
            make.edges.equalTo(self.view)
            return
        }
    }

    private func requerySuggestClient() {
        suggestClient?.query(searchQuery, callback: { suggestions, error in
            if let error = error {
                switch error.code {
                case SearchSuggestClientErrorInvalidEngine:
                    // Engine does not support search suggestions. Do nothing.
                    break
                case SearchSuggestClientErrorInvalidResponse:
                    println("Error: Invalid search suggestion data")
                    break
                default:
                    println("Error: \(error.description)")
                }
                self.searchSuggestions = []
                return
            }

            self.searchSuggestions = suggestions!
            self.searchSuggestions.removeRange(SuggestionsLimitCount..<self.searchSuggestions.count)
            self.tableView.reloadData()
        })
    }
}

extension SearchViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(ReuseIdentifier, forIndexPath: indexPath) as SearchTableViewCell

        if indexPath.row < searchSuggestions.count {
            cell.textLabel?.text = searchSuggestions[indexPath.row]
            cell.imageView?.image = nil
        } else {
            let searchEngine = sortedEngines[indexPath.row - searchSuggestions.count]
            cell.textLabel?.text = searchQuery
            cell.imageView?.image = searchEngine.image
        }

        // Make the row separators span the width of the entire table.
        cell.layoutMargins = UIEdgeInsetsZero

        return cell
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchSuggestions.count + sortedEngines.count
    }
}

extension SearchViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        var url: NSURL?
        if indexPath.row < searchSuggestions.count {
            let suggestion = searchSuggestions[indexPath.row]

            // Assume that only the default search engine can provide search suggestions.
            url = searchEngines?.defaultEngine.searchURLForQuery(suggestion)
        } else {
            let engine = sortedEngines[indexPath.row - searchSuggestions.count]
            url = engine.searchURLForQuery(searchQuery)
        }

        if let url = url {
            delegate?.didClickSearchResult(url)
        }
    }
}

private class SearchTableViewCell: UITableViewCell {
    private override func layoutSubviews() {
        super.layoutSubviews()
        self.imageView?.bounds = CGRectMake(0, 0, 24, 24)
    }
}