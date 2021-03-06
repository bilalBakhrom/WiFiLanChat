//
//  PeerBrowser.swift
//  WiFiLanChat
//
//  Created by Bilol Mamadjanov on 28/11/21.
//

import Network

// Update the UI when you receive new browser results.
protocol PeerBrowserDelegate: AnyObject {
    func refreshResults(results: Set<NWBrowser.Result>)
    func displayBrowseError(_ error: NWError)
}

/// An object to browse for available network services.
class PeerBrowser {
    private(set) var browser: NWBrowser?
    weak var delegate: PeerBrowserDelegate?

    // Create a browsing object with a delegate.
    init(delegate: PeerBrowserDelegate) {
        self.delegate = delegate
        createBrowser()
        startBrowsing()
    }
    
    /// Craetes a `NWBrowser` object
    private func createBrowser() {
        // Create parameters, and allow browsing over peer-to-peer link.
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        // Browse for a service type.
        browser = NWBrowser(for: .bonjour(type: PeerListener.serviceType, domain: nil), using: parameters)
    }

    /// Starts browsing for services.
    func startBrowsing() {
        // Handle state update.
        browser?.stateUpdateHandler = stateUpdateHandler(_:)
        // When the list of discovered endpoints changes, refresh the delegate.
        browser?.browseResultsChangedHandler = browseResultsChangedHandler(_:_:)
        // Start browsing and ask for updates on the main queue.
        browser?.start(queue: .main)
    }
    
    func cancel() {
        browser?.cancel()
    }
    
    /// A handler that receives browser state updates.
    private func stateUpdateHandler(_ newState: NWBrowser.State) {
        guard let browser = browser else {
            return
        }
        
        switch newState {
        case .failed(let error):
            // Restart the browser if it loses its connection
            if error == NWError.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection)) {
                print("Browser failed with \(error), restarting")
                browser.cancel()
                startBrowsing()
            } else {
                print("Browser failed with \(error), stopping")
                delegate?.displayBrowseError(error)
                browser.cancel()
            }
            
        case .ready:
            self.delegate?.refreshResults(results: browser.browseResults)
            
        default:
            break
        }
    }
    
    /// A handler that delivers updates about discovered services.
    private func browseResultsChangedHandler(_ results: Set<NWBrowser.Result>, _ changes: Set<NWBrowser.Result.Change>) {
        delegate?.refreshResults(results: results)
    }
}
