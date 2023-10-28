import Foundation
import Network

class SerialPortManager {
    let hostname: NWEndpoint.Host
    let port: NWEndpoint.Port
    var connection: NWConnection?

    init(hostname: String, port: UInt16) {
        self.hostname = NWEndpoint.Host(hostname)
        self.port = NWEndpoint.Port(rawValue: port)!
        self.startConnection()
    }

    func startConnection() {
        connection = NWConnection(host: hostname, port: port, using: .tcp)

        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Connected to the server")
            default:
                break
            }
        }

        connection?.start(queue: .global())
    }

    func send(data: Data) {
        connection?.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                print("Failed to send data with error: \(error)")
            }
        }))
    }

    func send(string: String) {
        if let data = string.data(using: .utf8) {
            send(data: data)
        }
    }

    func send(integer: UInt8, withNewline: Bool = true) {
        let data = Data([integer])
        send(data: data)
    }

}
