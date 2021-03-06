//
//  PeerConnection.swift
//  WiFiLanChat
//
//  Created by Bilol Mamadjanov on 27/11/21.
//

import Foundation
import Network

protocol PeerConnectionDelegate: NWConnectionStateDelegate, NWMessageReceiverDelegate {}

/// We will use this class to connect peers to send/receive data between them.
/// Data connection will be a bidirectional. Sent/Recieved data type will `Data`.
class PeerConnection {
    /// The object use to create a bidirectional data connection
    private var connection: NWConnection!
    /// The object that acts as the delegate of the connection.
    weak var delegate: PeerConnectionDelegate?
    
    /// The interface name
    var name: String? {
        if case let NWEndpoint.service(name, _, _, _) = connection.endpoint {
            return name
        } else {
            return nil
        }
    }
    
    /// Create an outbound connection when the user initiates a game.
    init(endpoint: NWEndpoint, interface: NWInterface?, passcode: String, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        self.connection = NWConnection(to: endpoint, using: NWParameters(passcode: passcode))
        
        startConnection()
    }
    
    /// Handle an inbound connection when the user receives a game request.
    init(connection: NWConnection, delegate: PeerConnectionDelegate) {
        self.delegate = delegate
        self.connection = connection
        
        startConnection()
    }
    
    /// Handle the user exiting the chat room.
    func cancel() {
        connection.cancel()
        connection = nil
    }
    
    /// Starts the peer-to-peer connection for both inbound and outbound connections.
    func startConnection() {
        guard let connection = connection else { return }
        // Handle state
        connection.stateUpdateHandler = stateUpdateHandler(_:)
        // Start the connection establishment.
        connection.start(queue: .main)
    }
    
    /// Sends message via created connection
    /// - Parameter message: The message to send
    func send(_ message: String) {
        guard let connection = connection else {
            return
        }
        
        let content = message.data(using: .utf8)
        let message = NWProtocolFramer.Message(messageType: .message)
        let context = NWConnection.ContentContext(identifier: "Message", metadata: [message])

        // Send the application content along with the message.
        connection.send(content: content, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    /// Sends data to notice that connection is going to be canceled.
    ///
    /// Call this method before close chat room
    func sendFrame(_ messageType: MessageType) {
        guard let connection = connection else {
            return
        }
        
        let message = NWProtocolFramer.Message(messageType: messageType)
        let context = NWConnection.ContentContext(identifier: "Cancel", metadata: [message])

        // Send the application content along with the message.
        connection.send(content: nil, contentContext: context, isComplete: true, completion: .idempotent)
    }
    
    /// Receives a message.
    ///
    /// It will continue to receive more messages untill receive an error.
    private func receiveNextMessage() {
        guard let connection = connection else { return }

        connection.receiveMessage { (content, context, isComplete, error) in
            // Extract your message type from the received context.
            if let message = context?.protocolMetadata(definition: ChatFramer.definition) as? NWProtocolFramer.Message {
                self.delegate?.received(content: content, message: message)
            }

            if error == nil {
                self.receiveNextMessage()
            }
        }
    }
    
    /// A handler that receives connection state updates.
    private func stateUpdateHandler(_ newState: NWConnection.State) {
        switch newState {
        case .preparing:
            delegate?.connectionPreparing()
        case .ready:
            connectionReady(connection)
        case .failed(let error), .waiting(let error):
            connectionFailed(connection, error: error)
        case .cancelled:
            delegate?.connectionCanceled()
        default:
            break
        }
    }
    
    /// The connection is established, and ready to send and receive data.
    /// - Parameter connection: A bidirectional data connection between a local endpoint and a remote endpoint.
    private func connectionReady(_ connection: NWConnection) {
        print("\(connection) established")
        // When the connection is ready, start receiving messages.
        receiveNextMessage()
        // Notify delegate that the connection is ready.
        delegate?.connectionReady()
    }
    
    /// The connection has disconnected or encountered an error.
    /// - Parameters:
    ///   - connection: A bidirectional data connection between a local endpoint and a remote endpoint.
    ///   - error: An error when connection is failed
    private func connectionFailed(_ connection: NWConnection, error: NWError) {
        print("\(connection) failed with \(error)")
        // Cancel the connection upon a failure.
        connection.cancel()
        // Notify delegate that the connection failed.
        delegate?.connectionFailed()
    }
}
